#!/usr/bin/env python3

import enum
import re
import shutil
import subprocess
from sys import exc_info
import time
import logging
import psutil
from collections import deque
from dataclasses import dataclass
from distutils.command.config import config
from pathlib import Path
from queue import Queue
from threading import Thread
from typing import Dict, List, NoReturn
from numpy import log

import yaml


class JobState(enum.Enum):
    READY = 'READY'
    FUZZING = 'FUZZING'
    COVERAGE_TRACING = 'COVERAGE_TRACING'
    SYNCING_RESULTS = 'SYNCING_RESULTS'
    FINISHED = 'FINISHED'
    FAILED = 'FAILED'
    EXIT_REQUESTED = 'EXIT_REQUESTED'

class Fuzzer(enum.Enum):
    FUZZTRUCTION = 'Fuzztruction'
    FUZZTRUCTION_NO_AFL = 'Fuzztruction-No-AFL'
    AFLPP = 'AFL++'
    WEIZZ = 'WEIZZ'
    SYMCC = 'SYMCC'

@dataclass
class Target():
    name: str
    config: Path

    def workdir(self) -> Path:
        cfg = yaml.load(self.config.read_text(), yaml.Loader)
        return Path(cfg['work-directory'])

@dataclass
class CampaignConfig:
    timeout_s: int
    first_run_id: int
    last_run_id: int
    fuzzers: List[Fuzzer]
    cores_total: int
    cores_per_target: int
    results_path: Path
    targets: List[Target]

    @staticmethod
    def parse_timeout_as_seconds(timeout: str) -> int:
        """
        Parse a timeout given as str, e.g., 60s, 12m, 4h, 1d as seconds.
        """
        match = re.match(r'([1-9][0-9]*)([smhd])', timeout)
        assert match
        assert len(match.groups()) == 2
        prefix = int(match.group(1))

        suffix = match.group(2)
        suffix_to_factor = {
            's': 1,
            'm': 60,
            'h': 3600,
            'd': 3600 * 24,
        }

        factor = suffix_to_factor.get(suffix, None)
        if factor is None:
            raise ValueError(f'Unknown timeout suffix: {suffix}')

        seconds = prefix * factor
        return seconds

    @staticmethod
    def parse_fuzzers(fuzzers: List[str]) -> List[Fuzzer]:
        ret = []
        for f in fuzzers:
            f = Fuzzer(f)
            ret.append(f)
        return ret

    @staticmethod
    def parse_targets(targets: Dict[str, Dict[str, str]]) -> List[Target]:
        ret = []
        for target, target_attrs in targets.items():
            config_path = Path(target_attrs['config']).expanduser().resolve()
            ret.append(Target(target, config_path))
        return ret

    @staticmethod
    def from_path(path: Path) -> 'CampaignConfig':
        config_file = Path(path)
        config = yaml.load(config_file.read_text(), yaml.Loader)

        timeout_s = CampaignConfig.parse_timeout_as_seconds(config['timeout'])
        first_run_id = int(config['first_run_id'])
        last_run_id = int(config['last_run_id'])
        if first_run_id < 0 or last_run_id < 0:
            raise ValueError('Negative first/last ids not allowed')
        if last_run_id < first_run_id:
            raise ValueError('first_run_id must be <= last_run_id')
        fuzzers = CampaignConfig.parse_fuzzers(config['fuzzers'])
        cores_total = int(config['cores-total'])
        if cores_total < 2:
            raise ValueError('cores_total must be >= 2')
        cores_per_target = int(config['cores-per-target'])
        if cores_per_target < 2:
            raise ValueError('cores_per_target must be >= 2')
        results_path = Path(config['results-path']).expanduser().resolve()
        targets = CampaignConfig.parse_targets(config['targets'])

        ret = CampaignConfig(
            timeout_s=timeout_s,
            first_run_id=first_run_id,
            last_run_id=last_run_id,
            fuzzers=fuzzers,
            cores_total=cores_total,
            cores_per_target=cores_per_target,
            results_path=results_path,
            targets=targets,
        )
        return ret

class FuzzingJob:

    def __init__(self, target: Target, run_id: int, timeout_s: int, cores: int, fuzzer: Fuzzer, log_dir: Path, results_dir: Path):
        self._target = target
        self._run_id = run_id
        self._timeout_s = timeout_s
        # Needed if two fuzzers are running together (e.g., FT + AFL)
        assert cores >= 2
        self._cores = cores
        self._state = JobState.READY
        self._start_ts = None
        self._fuzzer = fuzzer
        self._exit_requested = False
        self._worker: Thread = None
        self._log_dir = log_dir
        self._results_dir = results_dir
        self.log = self._setup_logger()

    def _setup_logger(self):
        log_path = self._log_dir / f'{self.name()}-scheduler.log'
        logger = logging.getLogger(self.name())
        file_handler = logging.FileHandler(log_path)
        logger.addHandler(file_handler)
        logger = logging.LoggerAdapter(logger, {'job_name': self.name()})
        return logger

    def cores(self) -> int:
        """
        Number of cores required by this job.
        """
        return self._cores

    def state(self) -> JobState:
        """
        The current state of the fuzzing job.
        """
        return self._state

    def start(self):
        """
        Start the fuzzing job. After calling this, the jobs state
        is different to JobState.READY.
        """
        self.log.info('Starting fuzzing job')
        assert self._state == JobState.READY
        self._state = JobState.FUZZING
        self._start_ts = time.monotonic()
        self._worker = Thread(target=self._loop)
        self._worker.start()

    def request_exit(self):
        """
        Request to terminate the worker, instead of waiting for the job to be finished.
        This will cause all the job's data to be lost, if they have not been processed.
        """
        self.log.info('Got exit request')
        self._exit_requested = True

    def _run_tracing(self):
        """
        Trace the coverage for all found inputs are store it into the jobs workdir.
        """
        self.log.info('Starting tracing')
        self._state = JobState.COVERAGE_TRACING

        tracing_cmd = [
            '/usr/bin/sudo',
            Path('~/fuzztruction/target/debug/fuzztruction').expanduser().resolve().as_posix(),
            self._target.config.as_posix(),
            '--suffix', self.suffix(),
            'tracer',
            '-t', f'{self._timeout_s}s',
            '-j', str(self.cores())
        ]
        self.log.info(f'Tracing command: {" ".join(tracing_cmd)}')
        log_path = self._log_dir / f'{self.fuzzer_workdir().name}-tracing.log'
        tracing_process = subprocess.Popen(tracing_cmd, stdin=subprocess.DEVNULL, stdout=log_path.open('w'), stderr=subprocess.STDOUT)

        while tracing_process.poll() is None:
            if self.exit_requested():
                pid = tracing_process.pid
                subprocess.call(f'sudo kill {pid}', shell=True)
                tracing_process.wait(60)
                self._state = JobState.EXIT_REQUESTED
                raise InterruptedError('Exit requested')
        self.log.info('Tracing finished')

    def _sync_results(self):
        """
        Sync the coverage files from the job into the results directory and
        delete everything else.
        """
        src = self.fuzzer_workdir()
        dst = self._results_dir
        self.log.info(f'Syncing {src} to {dst}')
        log_path = self._log_dir / f'{self.fuzzer_workdir().name}-syncing.log'
        cmd = f"sudo rsync -arv --include='/*' --include='traces/' --include='traces/**' --exclude='*' --prune-empty-dirs {src.as_posix()} {dst.as_posix()}"
        self.log.info(f'Sync cmd: {cmd}')
        subprocess.check_call(cmd, stdin=subprocess.DEVNULL, stdout=log_path.open('w'), stderr=subprocess.STDOUT, shell=True)
        #shutil.rmtree(src, ignore_errors=True)
        self.log.info('Syncing finshed')

    def exit_requested(self):
        return self._exit_requested

    def name(self) -> str:
        """
        Get a unique name for this worker.
        """
        return self.fuzzer_workdir().name

    def fuzzer_workdir(self) -> Path:
        """
        Return the `Path` to the fuzzer jobs workdir.
        NOTE: This naming schema depends on the suffix schema implemented in Fuzztruction.
        """
        workdir = self._target.workdir().as_posix()
        workdir += f'-{self.suffix()}'
        return Path(workdir)

    def purge_workdir(self):
        """
        Delete the working directory of the job.
        """
        workdir = self.fuzzer_workdir()
        self.log.info(f'Purging workdir {workdir}')
        shutil.rmtree(workdir, ignore_errors=True)

    def suffix(self):
        return f'{self._fuzzer.value}-{self._timeout_s}s-{self._run_id}'

    def join(self):
        if self._worker:
            self._worker.join()

    def __str__(self):
        ret = f'{self.__class__.__name__}(fuzzer={self._fuzzer}, target={self._target}, run_id={self._run_id})'
        return ret

    def _loop(self) -> None:
        raise NotImplementedError()

    def _terminate(self) -> None:
        raise NotImplementedError()

class AflPlusPlusJob(FuzzingJob):

    def __init__(self, target: Target, run_id: int, timeout_s: int, cores: int, fuzzer: Fuzzer, log_dir: Path, results_dir: Path):
        super().__init__(target, run_id, timeout_s, cores, fuzzer, log_dir, results_dir)
        self._subprocesses: List[subprocess.Popen[bytes]] = []

    def _spawn_other_fuzzing_process(self) -> int:
        return self.cores()

    def _loop(self) -> None:
        self.purge_workdir()

        cores_left = self._spawn_other_fuzzing_process()
        time.sleep(10)

        if cores_left > 0:
            afl_cmd = [
                '/usr/bin/sudo',
                Path('~/fuzztruction/target/debug/fuzztruction').expanduser().resolve().as_posix(),
                self._target.config.as_posix(),
                '--suffix', self.suffix(),
                'aflpp',
                '-t', f'{self._timeout_s}s',
                '-j', str(cores_left)
            ]
            self.log.info(f'AFL++ command: {" ".join(afl_cmd)}')
            log_path = self._log_dir / f'{self.fuzzer_workdir().name}-aflworker.log'
            process = subprocess.Popen(afl_cmd, stdin=subprocess.DEVNULL, stdout=log_path.open('w'), stderr=subprocess.STDOUT)
            self._subprocesses.append(process)

        try:
            while not self.exit_requested():
                time.sleep(1)
                if all(map(lambda e: e.poll() != None, self._subprocesses)):
                    # All are terminated
                    self._run_tracing()
                    self._sync_results()
                    break
        except InterruptedError:
            self.log.warning(f'Interrupted while executing worker')
            self._terminate()
        except Exception as _:
            self.log.warning(f'Error while executing worker', exc_info=True)
            self._state = JobState.FAILED
            self._terminate()
        else:
            self.log.info('Job finished')
            self._state = JobState.FINISHED

        if self.exit_requested():
            # Termination was explicitly requested, thus we need to kill the processes.
            self._terminate()


    def _terminate(self):
        self.log.info(f'Terminating worker')

        for process in self._subprocesses:
            pid = process.pid
            subprocess.call(f'sudo kill {pid}', shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        for process in self._subprocesses:
            process.wait(60)


class FuzztructionJob(AflPlusPlusJob):

    def __init__(self, target: Target, run_id: int, timeout_s: int, cores: int, fuzzer: Fuzzer, log_dir: Path, results_dir: Path, no_afl: bool=False):
        self._no_afl = no_afl
        super().__init__(target, run_id, timeout_s, cores, fuzzer, log_dir, results_dir)

    def _spawn_other_fuzzing_process(self) -> int:
        if self._no_afl:
            ft_cores = self.cores()
            afl_cores = 0
        else:
            ft_cores = self.cores() // 2
            afl_cores = self.cores() - ft_cores

        # Start the fuzzing process
        ft_cmd = [
            '/usr/bin/sudo',
            Path('~/fuzztruction/target/debug/fuzztruction').expanduser().resolve().as_posix(),
            self._target.config.as_posix(),
            '--suffix', self.suffix(),
            'fuzz',
            '-t', f'{self._timeout_s}s',
            '-j', str(ft_cores)
        ]
        self.log.info(f'FT (no_afl={self._no_afl}) command: {" ".join(ft_cmd)}')

        log_path = self._log_dir / f'{self.fuzzer_workdir().name}-ftworker.log'
        process = subprocess.Popen(ft_cmd, stdin=subprocess.DEVNULL, stdout=log_path.open('w'), stderr=subprocess.STDOUT)
        self._subprocesses.append(process)

        return afl_cores


class WeizzJob(AflPlusPlusJob):

    def _spawn_other_fuzzing_process(self) -> int:
        weizz_cores = self.cores()

        # Start the fuzzing process
        weizz_cmd = [
            '/usr/bin/sudo',
            Path('~/fuzztruction/target/debug/fuzztruction').expanduser().resolve().as_posix(),
            self._target.config.as_posix(),
            '--suffix', self.suffix(),
            'aflpp',
            '-t', f'{self._timeout_s}s',
            '-j', '0',
            '--weizz-jobs', str(weizz_cores)
        ]
        self.log.info(f'WEIZZ command: {" ".join(weizz_cmd)}')

        log_path = self._log_dir / f'{self.fuzzer_workdir().name}-weizz.log'
        process = subprocess.Popen(weizz_cmd, stdin=subprocess.DEVNULL, stdout=log_path.open('w'), stderr=subprocess.STDOUT)
        self._subprocesses.append(process)
        time.sleep(5)

        return 0

    # let job_cnt = matches
    #     .value_of("jobs")
    #     .map(|e| e.parse().unwrap())
    #     .unwrap();
    # let symcc_job_cnt = matches
    #     .value_of("symcc-jobs")
    #     .map(|e| e.parse().unwrap())
    #     .unwrap();
    # let weizz_job_cnt = matches
    #     .value_of("weizz-jobs")
    #     .map(|e| e.parse().unwrap())
class SymccJob(AflPlusPlusJob):

    def _spawn_other_fuzzing_process(self) -> int:
        symcc_jobs = self.cores() // 2
        afl_jobs = self.cores() - symcc_jobs

        # Start the fuzzing process
        symcc_cmd = [
            '/usr/bin/sudo',
            Path('~/fuzztruction/target/debug/fuzztruction').expanduser().resolve().as_posix(),
            self._target.config.as_posix(),
            '--suffix', self.suffix(),
            'aflpp',
            '-t', f'{self._timeout_s}s',
            '-j', str(afl_jobs),
            '--symcc-jobs', str(symcc_jobs)
        ]
        self.log.info(f'SYMCC command: {" ".join(symcc_cmd)}')

        log_path = self._log_dir / f'{self.fuzzer_workdir().name}-symcc.log'
        process = subprocess.Popen(symcc_cmd, stdin=subprocess.DEVNULL, stdout=log_path.open('w'), stderr=subprocess.STDOUT)
        self._subprocesses.append(process)
        time.sleep(5)

        return 0


class EvaluationCampaign:

    def __init__(
            self,
            config: CampaignConfig,
            logger: logging.LoggerAdapter,
            log_dir: Path
        ) -> None:
        self._config = config
        self._allocated_cores = 0
        self._max_cores = config.cores_total
        self._pending_jobs = deque(EvaluationCampaign.generate_jobs(config, log_dir))
        self._running_jobs: List[FuzzingJob] = []
        self._jobs_done: List[FuzzingJob] = []
        self.log = logger


    @staticmethod
    def generate_jobs(config: CampaignConfig, log_dir: Path) -> List[FuzzingJob]:
        SYMCC_UNSUPPORTED_TARGETS = ("7zip_7zip", "7zip-enc_7zip-dec", "sign_vfychain")
        jobs: List[FuzzingJob] = []
        for id in range(config.first_run_id, config.last_run_id + 1):
            for fuzzer in config.fuzzers:
                for target in config.targets:
                    if fuzzer == Fuzzer.FUZZTRUCTION:
                        j = FuzztructionJob(target, id, config.timeout_s, config.cores_per_target, fuzzer, log_dir, config.results_path)
                        jobs.append(j)
                    elif fuzzer == Fuzzer.FUZZTRUCTION_NO_AFL:
                        j = FuzztructionJob(target, id, config.timeout_s, config.cores_per_target, fuzzer, log_dir, config.results_path, no_afl=True)
                        jobs.append(j)
                    elif fuzzer == Fuzzer.AFLPP:
                        j = AflPlusPlusJob(target, id, config.timeout_s, config.cores_per_target, fuzzer, log_dir, config.results_path)
                        jobs.append(j)
                    elif fuzzer == Fuzzer.SYMCC:
                        if target.name in SYMCC_UNSUPPORTED_TARGETS:
                            print(f'Skipping unsupported target {target.name} for SYMCC')
                            continue

                        j = SymccJob(target, id, config.timeout_s, config.cores_per_target, fuzzer, log_dir, config.results_path)
                        jobs.append(j)
                    elif fuzzer == Fuzzer.WEIZZ:
                        j = WeizzJob(target, id, config.timeout_s, config.cores_per_target, fuzzer, log_dir, config.results_path)
                        jobs.append(j)
                    else:
                        assert(False)
        return jobs

    def start_next_job(self):
        if len(self._pending_jobs) == 0:
            return
        if self._allocated_cores >= self._config.cores_total:
            return
        next_job: FuzzingJob = self._pending_jobs.popleft()
        next_job.start()
        assert next_job.state != JobState.READY
        self._running_jobs.append(next_job)
        self._allocated_cores += self._config.cores_per_target
        self.log.info(f'Allocated cores: {self._allocated_cores}')

    def check_running_jobs(self):
        for job in self._running_jobs.copy():
            if job.state() in [JobState.FINISHED, JobState.FAILED]:
                self.log.info(f'Job {job} terminated with state {job.state()}')
                self._running_jobs.remove(job)
                self._jobs_done.append(job)
                self._allocated_cores -= self._config.cores_per_target
                self.log.info(f'Allocated cores: {self._allocated_cores}')

    def check_if_finished(self):
        return len(self._pending_jobs) == 0 and len(self._running_jobs) == 0

    def start(self):
        while True:
            time.sleep(3)
            self.check_running_jobs()
            self.start_next_job()
            if self.check_if_finished():
                self.log.info('All jobs finished.')
                break

    def stop_and_join(self):
        for j in self._running_jobs:
            j.request_exit()
        for j in self._running_jobs:
            j.join()

def setup_logger(log_dir: Path) -> logging.Logger:
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)

    handler = logging.StreamHandler()
    formatter = logging.Formatter('[%(asctime)s][%(job_name)s][%(levelname)s][%(filename)s:%(lineno)d][%(funcName)s()]: %(message)s')
    handler.setFormatter(formatter)
    root_logger.addHandler(handler)

    shutil.rmtree(log_dir, ignore_errors=True)
    log_dir.mkdir(parents=True)

    log_path = log_dir / 'main.log'
    logger = logging.getLogger()
    file_handler = logging.FileHandler(log_path)
    logger.addHandler(file_handler)
    return logging.LoggerAdapter(logger, {'job_name': 'Main'})

def check_env(log: logging.LoggerAdapter):
    def yes_or_terminate():
        answer = input('Continue anyway? [y/n]: ')
        if answer.lower() == 'n':
            exit(1)

    mem_file = Path('/proc/meminfo')
    meminfo = mem_file.read_text()
    total_mem_kb = re.match(r'MemTotal:.*?(\d+)', meminfo)
    assert total_mem_kb
    total_mem_kb = int(total_mem_kb.group(1))

    total_swap_kb = re.search(r'SwapTotal:.*?(\d+)', meminfo)
    if total_swap_kb is None:
        total_swap_kb = 0
    else:
        total_swap_kb = int(total_swap_kb.group(1))

    if total_mem_kb < (1024 * 1024 * 32):
        log.warning('You should have at least 32 GiB of memory.')
        yes_or_terminate()

    # Recommended are 600 GiB
    needed_kb = 1024 * 1024 * 600
    mem_plus_swap_kb = total_mem_kb + total_swap_kb
    if mem_plus_swap_kb < needed_kb:
        log.warning('Total memory (RAM+SWAP) is smaller than 500 GiB. This might cause some targets fail to run.')
        needed_swap_gib = ((needed_kb - mem_plus_swap_kb) // 1024 // 1024) + 5
        cmds = f'SWAP=/swap\nsudo fallocate -l {needed_swap_gib}GiB $SWAP\nsudo mkswap $SWAP\nsudo chmod 600 $SWAP\nsudo swapon $SWAP'
        log.warning(f'You should consider adding more SWAP space. Run the following command outside of the container:\n{cmds}')
        yes_or_terminate()

    free_tmp_space_kb = psutil.disk_usage('/tmp').total // 1024
    if free_tmp_space_kb < needed_kb:
        log.warning(f'The /tmp directory is to small. This might cause some targets to fail. You should run sudo mount -o remount,size={needed_kb//1000//1000}G /tmp to increase the size of /tmp.')
        yes_or_terminate()

    cmd = 'echo 0 | sudo tee /proc/sys/fs/suid_dumpable'
    log.info(f'Setting suid_dumpable: {cmd} ')
    subprocess.check_call(cmd, shell=True)

    cmd = 'echo core | sudo tee /proc/sys/kernel/core_pattern'
    log.info(f'Setting core_pattern: {cmd} ')
    subprocess.check_call(cmd, shell=True)

    cmd = 'echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
    log.info(f'Setting scaling_governor: {cmd} ')
    subprocess.check_call(cmd, shell=True)


log_dir = Path('logs')
logger = setup_logger(log_dir)
check_env(logger)

cfg = CampaignConfig.from_path('campaign.yml')
eval_campaign = EvaluationCampaign(cfg, logger, log_dir)

try:
    eval_campaign.start()
except KeyboardInterrupt:
    logger.info('Got keyboard interrupt, stopping campaign.')
    eval_campaign.stop_and_join()
except:
    logger.error('Unexpected error.', exc_info=True)

logger.info('Exiting')
