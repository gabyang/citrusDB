#!/bin/bash

scp -r 4224:/home/stuproj/cs4224b/tyx021/test-run/*.csv ./result/

for file in ./result/*; do
    echo "Result of the run on: $(date +"%Y-%m-%d %H:%M:%S")" >> "$file"
done

