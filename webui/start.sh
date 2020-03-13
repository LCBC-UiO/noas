# exit on errors
set -ETeuo pipefail

declare BASEDIR; BASEDIR="$( cd "$( dirname $0 )/" && pwd )"; readonly BASEDIR

export FLASKR_SETTINGS_DEFAULT=${BASEDIR}/../config_default.txt
export FLASKR_SETTINGS_OVERRIDE=${BASEDIR}/../config.txt

python3 ${BASEDIR}/main.py



#export SINGULARITY_BINDPATH=/etc/hosts
