#!/bin/bash

n=( 513 ) # 512 1024
np=( 1073741824 ) # 1073741824 8589934592
nt=( 10 )
nodes=( 1 )
parent_dir=$PWD

for g in "${nodes[@]}"
do
    echo $g
    dir="FFT_strong_scaling/${n}_${nt}/nodes_$g"
    mkdir -p "$dir"
    cp "jobscript_fft.tmpl" "$dir/jobscript.sh"
    sed -i "s/_nx_/${n}/g" "$dir/jobscript.sh"
    sed -i "s/_ny_/${n}/g" "$dir/jobscript.sh"
    sed -i "s/_nz_/${n}/g" "$dir/jobscript.sh"
    sed -i "s/_np_/${np}/g" "$dir/jobscript.sh"
    sed -i "s/_nt_/${nt}/g" "$dir/jobscript.sh"
    sed -i "s/_nodes_/$g/g" "$dir/jobscript.sh"
    cd "$dir"
    sbatch jobscript.sh
    cd "$parent_dir"
done
