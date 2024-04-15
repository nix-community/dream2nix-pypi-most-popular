# Source: https://hugovk.github.io/top-pypi-packages/

curl https://hugovk.github.io/top-pypi-packages/top-pypi-packages-30-days.min.json \
    | jq -r '.rows[:500][] | .project' \
    > 500-most-popular-pypi-packages.txt
