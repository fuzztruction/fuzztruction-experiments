#!/usr/bin/env python3
"""
Plot coverage data. This creates Figure 3 in the paper (as file all_coverage.pdf)

## Dependencies (Latex for font)
# sudo apt install texlive texlive-latex-extra texlive-fonts-recommended dvipng cm-super
"""
import matplotlib.pyplot as plt
from dataclasses import dataclass
from collections import defaultdict
from matplotlib.pyplot import Figure, Axes
from pathlib import Path
from statistics import mean, median
from typing import Dict, List, Tuple
import sys


# fuzzing run configuration
# * runtime in seconds
runtime = 24 * 3600
# * number of parallel runs
NUM_RUNS = 5

# Targets and their position as (column, row) in the plot
TARGETS_TO_POSITION = {
    # first row
    "genrsa_rsa"              : (0, 0),
    "gendsa_dsa"              : (1, 0),
    "sign_vfychain"           : (2, 0),
    # second row
    "7zip-enc_7zip-dec"       : (0, 1),
    "qpdf-enc_pdftotext"      : (1, 1),
    "pngtopng_pngtopng"       : (2, 1),
    # third row
    "7zip_7zip"               : (0, 2),
    "pdfseparate_pdftotext"   : (1, 2),
    "mke2fs_e2fsck"           : (2, 2),
    # fourth row
    "objcopy_objdump"         : (0, 3),
    "objcopy_readelf"         : (1, 3),
    "zip_unzip"               : (2, 3),
}

# fuzzers may fail to build for some targets -- add these here
UNSUPPORTED_TARGETS = {
    "SYMCC" : ["7zip_7zip", "7zip-enc_7zip-dec", "sign_vfychain"]
}


# Plot configuration
# * colors used
COLORS: Dict[str, str] = {
   "red"      : "#A83700",
   "darkblue" : "#2C4959",
   "gray"     : "#616161",
   "green"    : "#33932E",
   "amber"    : "#FF7E00",
}
# * space between markers
N = 90
# * number of fuzzers
NUM_FUZZERS = 5
# * per-fuzzer plot configuration, e.g., which color or marker to use
FUZZERS = {
    "Fuzztruction-No-AFL" : {
        "label" : "Fuzztruction-NoAFL",
        "color" : COLORS["red"],
        "marker": "o",
        "markersize" : 4,
        "markevery" : (0, N*NUM_FUZZERS),
        "linestyle" : "solid",
    },
    "Fuzztruction" : {
        "label" : "Fuzztruction",
        "color" : COLORS["amber"],
        "marker" : "s",
        "markersize" : 4,
        "markevery" : (N, N*NUM_FUZZERS),
        "linestyle" : "solid",
    },
    "AFL++" : {
        "label" : "AFL++",
        "color" : COLORS["darkblue"],
        "marker" : "v",
        "markersize" : 4,
        "markevery" : (N*2, N*NUM_FUZZERS),
        "linestyle" : "solid",
    },
    "SYMCC" : {
        "label" : "SymCC",
        "color" : COLORS["green"],
        "marker" : "^",
        "markersize" : 4,
        "markevery" : (N*3, N*NUM_FUZZERS),
        "linestyle" : "solid",
    },
    "WEIZZ" : {
        "label" : "Weizz",
        "color" : COLORS["gray"],
        "marker" : "d",
        "markersize" : 4,
        "markevery" : (N*4, N*NUM_FUZZERS),
        "linestyle" : "solid",
    }
}


@dataclass
class PlotData(object):
    """
    Holds data used to plot a fuzzing run
    """
    seconds: List[int]
    raw_bbs: List[List[int]]
    medians: List[float]
    intervals: List[Tuple[int, int]]


def parse(path: Path) -> List[Tuple[int, int]]:
    with open(path, "r", encoding="utf8") as f:
        content = [l.strip() for l in f.readlines() if l.strip()]
    res: List[Tuple[int, int]] = []
    d: Dict[int, int] = defaultdict(int)
    assert len(content) >= 2, \
        f"Expected more than 1 lines, found {len(content)} in {path.as_posix()}"
    # skip column header
    content = content[1:]
    for l in content:
        lhs, rhs = l.split(";", 1)
        discovery_ts = int(lhs.strip())
        num_new_unique_bbs = int(rhs.strip())
        d[discovery_ts] = num_new_unique_bbs
    num_bbs_found = 0
    for cur_ts in range(runtime):
        num_bbs_found += d[cur_ts]
        res.append((cur_ts, num_bbs_found))
    assert num_bbs_found > 0, f"{path} reports no basic blocks found!"
    return res


def plot(data: Dict[str, PlotData], target: str, ax: Axes) -> None:
    """
    Plots data as a line (i.e., one fuzzer for one target)
    """
    # tick at each hour, label only every 4h
    xticks = list(map(lambda t: 3600 * t, range(runtime // 3600)))
    xtick_labels = [str(t) if t % 4 == 0 else "" for t in range(runtime//3600)]
    ax.set_xticks(xticks)
    ax.set_xticklabels(xtick_labels)
    ax.set_title(target)

    for name, fuzzer_data in data.items():
        ax.plot(
            fuzzer_data.seconds,
            fuzzer_data.medians,
            **FUZZERS[name]
        )
        if fuzzer_data.intervals:
            lower = [l for (l, _) in fuzzer_data.intervals]
            upper = [h for (_, h) in fuzzer_data.intervals]
            assert len(lower) == len(upper), f"{target}:{name}: Upper and lower 60 percentile have different #data points"
            assert len(lower) == len(fuzzer_data.seconds), f"{target}:{name}: CI has too few data points"
            ax.fill_between(
                fuzzer_data.seconds, lower, upper, color=FUZZERS[name]["color"],
                alpha=.3
            )
        else:
            print(f"{target}:{name}: No ci data")

    ax.set_ylim(ymin=0)
    # remove top & right line
    ax.spines["right"].set_visible(False)
    ax.spines["top"].set_visible(False)

    ax.legend(loc="lower right")


def plot_target_median(raw_data: Dict[str, List[List[Tuple[int, int]]]],
                        target: str, ax: Axes) -> Figure:
    """
    Given raw data for a single target, plot each fuzzer for this target 
    """
    fuzzer_data: Dict[str, PlotData] = {}
    for fuzzer, runs in raw_data.items():
        print(f"{target}:{fuzzer}: plotting median of {len(runs)} runs")
        all_raw_bbs: List[List[int]] = []
        medians: List[float] = []
        intervals: List[Tuple[int, int]] = []
        seconds = list(range(runtime))

        if not runs:
            print(f"[!] {target}:{fuzzer}: No runs found")
            continue

        for sec in seconds:
            # plot only each minute
            if sec % 60 != 0:
                continue
            secs = {run[sec][0] for run in runs}
            # sanity check
            assert len(secs) == 1 and sec in secs, f"expected {sec}, got {secs}"
            raw_bbs = [run[sec][1] for run in runs]
            all_raw_bbs.append(raw_bbs)
            medians.append(median(raw_bbs))
            # intervals are hardcoded for 5 runs (and skipped otherwise) 
            if len(raw_bbs) == 5:
                lower, _, upper = sorted(raw_bbs)[1:-1]
                intervals.append((lower, upper))
            else:
                print(
                    f"[!] {target}{fuzzer}: Intervals work only if 5 runs are available " \
                    f"-- found only {len(raw_bbs)} runs"
                )
        fuzzer_data[fuzzer] = PlotData(
            # plot only each minute => need to prune seconds
            seconds=[s for s in seconds if s % 60 == 0],
            raw_bbs=all_raw_bbs,
            medians=medians,
            intervals=intervals
        )
    return plot(fuzzer_data, target=target, ax=ax)



def extract_data(base_dir: Path, target: str, fuzzer_names: List[str],
            num_runs: int) -> Dict[str, List[List[Tuple[int, int]]]]:
    """
    extract data in coverage.csv files for num_runs and fuzzer suffix
    """
    all_data: Dict[str, List[List[Tuple[int, int]]]] = {}
    for fuzzer in fuzzer_names:
        # check if we know this fuzzer (and have a plot configuration)
        assert fuzzer in FUZZERS, f"Fuzzer {fuzzer} is not a known fuzzer (known: {list(FUZZERS.keys())})"
        # some fuzzers (looking at you, symcc) can't run specific targets
        if target in UNSUPPORTED_TARGETS.get(fuzzer, []):
            print(f"{target}: {fuzzer} does not support this target")
            continue
        # identify all relevant directories
        run_dirs = []
        for i in range(1, num_runs+1):
            # match expected run dir
            run_dir = base_dir / f"{target}-{fuzzer}-{runtime}s-{i}"
            if not run_dir.exists():
                print(f"[!] Failed to find run directory {run_dir.as_posix()}")
                continue
            if not (run_dir / "coverage.csv").exists():
                print(f"[!] Directory {run_dir.as_posix()} does not contain a coverage.csv")
                continue
            run_dirs.append(run_dir)
        # read coverage.csv files and parse data
        data = [parse(dir / "coverage.csv") for dir in run_dirs]
        if len(data) != num_runs:
            print(f"[!] Expected {num_runs} runs but found {len(data)}")
        # save data
        all_data[fuzzer] = data
    return all_data


def plot_all_targets() -> None:
    """
    Plot medians of all fuzzers for all targets
    """
    global runtime
    args = sys.argv
    if len(args) != 3:
        print(f'[!] Usage: {args[0]} <runtime-in-seconds> <directory-containing-all-runs>')
        exit(1)
    done_runs_dir = Path(args[2])
    runtime = int(args[1])

    params = {
        "text.usetex" : True,
        "mathtext.fontset" : "stix",
        "font.family" : "STIXGeneral",
    }

    plt.rcParams.update(params)

    # rows * columns must match the number of targets
    rows = 4
    columns = 3
    fig, axes = plt.subplots(rows, columns, figsize=(4.5*columns, 3*rows))
    targets = list(TARGETS_TO_POSITION.keys())

    print(f"Found {len(list(targets))} targets")
    assert len(targets) <= sum(map(len, axes)), f"More targets ({len(targets)}) than subplots ({sum(map(len, axes))})"

    # read data for each target
    for target in sorted(list(targets)):
        print(f"{target}: Processing..")
        plot_data = extract_data(
            done_runs_dir, target, ["Fuzztruction", "Fuzztruction-No-AFL", "AFL++", "SYMCC", "WEIZZ"], NUM_RUNS
        )

        col, row = TARGETS_TO_POSITION[target]
        plot_target_median(plot_data, target=target, ax=axes[row][col])
        print()

    fig.supxlabel("Time [h]", fontsize="large")
    fig.supylabel("\#Covered Basic Blocks", fontsize="large")

    fig.tight_layout()
    name = "./all_coverage.pdf"
    print(f"Writing to file {name}")
    plt.savefig(name)


if __name__ == "__main__":
    plot_all_targets()
