Ocaml Search Code

# Description

Algorithms and domains produced by the UNH Artificial Intelligence research
group between 2006-2014.  I certainly can't claim sole ownership of the code.
Many researchers contributed to the code base over these years, and their names
are captured in @author tags in various files.

Please direct questions to Jordan Thayer.

# State Of The Code

This is a snapshot of the research code around 2012, when the group switched to
doing much of it's research in C++ for performance reasons.

Everything relies on a custom build tool, ocm2, to build.  You'll need to
bootstrap ocm2 by building ocm first.  Once ocm2 is built, you should be able to
build solvers and instance generators directly.

# Coming Soon

An actual description of the directiories and their contents.
Also some build instructions and documentation.

# Maniphest

## Top Level

README.MD  -- This file

my_clean.sh -- ```make clean``` for the whole research project


## Domains
vacuum
tsp
dyn_robot
job_shop
msa
pancake
scanalyzer
dock_robot
darts
manufacturing
openstacks
rubiks
solitaire_chess
roadmap
sokoban
sudoku
hanoi
luigi
grid
sliding_tiles
topspin
rucksack
vis_nav
setcover
logistics
partition
plan-it
tplan
motion_prim
orc
csp

## Solvers
blfs
bounded_depth
iterative_deepening
search

## Visualizations
image
search_vis
spt
spt_plot

## Utilities
experiments
histogram
pdb
rdb
structs
user_paths
wrutils
wrmath
wrthreads

## Build Tools
ocm
ocm2

## Toys
gtk_playground
libplayerc_caml
make_tables
synthetic_graph

## Learning
bvls
learning
offline_fitting
online
