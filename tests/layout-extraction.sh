#!/bin/bash -e
# This file is based on start_vnc.sh from:
# https://github.com/iic-jku/IIC-OSIC-TOOLS
#
# Run this test from the root of the repository
# ./tests/layout-extraction.sh

# Load options from env file in case exists
ENVFILE=".env"
if [ -f "${ENVFILE}" ]; then
	source "${ENVFILE}"
fi


# SET THE SHARED DIR PATH
if [ -z ${SHARED_DIR+z} ]; then
    SHARED_DIR=$(pwd)"/tests"
fi

# Doesn't require to expose ports just docker related configs!
if [ -z ${DOCKER_USER+z} ]; then
	DOCKER_USER="isaiassh"
fi

if [ -z ${DOCKER_IMAGE+z} ]; then
	DOCKER_IMAGE="unic-cass-tools"
fi

if [ -z ${DOCKER_TAG+z} ]; then
	DOCKER_TAG="1.0.6"
fi


PDK=ihp-sg13g2
USER_ID=1000
USER_GROUP=1000
DOCKER_IMAGE_TAG=${DOCKER_USER}/${DOCKER_IMAGE}:${DOCKER_TAG}

CONTAINER_NAME=${DOCKER_IMAGE}"_test"
CONTAINER_SHARED_DIR="/home/designer/shared"

echo ">>> 1. Starting a test container $CONTAINER_NAME using the image $DOCKER_IMAGE_TAG"

docker run -d --user "${USER_ID}:${USER_GROUP}"  \
	--mount type=bind,source=${SHARED_DIR},target=${CONTAINER_SHARED_DIR} \
	-e SHELL=/bin/bash \
	-e PDK=${PDK} \
	-e USER_ID=${USER_ID} \
	-e USER_GROUP=${USER_GROUP} \
  --entrypoint "/bin/bash" \
  --name ${CONTAINER_NAME} ${DOCKER_IMAGE_TAG} -c "trap : TERM INT; sleep infinity & wait"

CMD="docker exec -it ${CONTAINER_NAME} /bin/bash -c "

GDS="~/shared/artifacts/test_inv.gds"
CELL="test_inv"

echo ">>> 2. Compiling PDK"
$CMD "/bin/bash ~/.bashrc"

echo ">>> 3. Preparing the environment"
CONTAINER_RCFILE="/opt/pdks/ihp-sg13g2/libs.tech/magic/ihp-sg13g2.magicrc"

RUN_DIR="${SHARED_DIR}/run"
CONTAINER_RUN_DIR="${CONTAINER_SHARED_DIR}/run"

#Create the directory in case doesn't exist
mkdir -p $RUN_DIR

STARTING_PWD=$(pwd)

#Temporary rc file witn commands that will be loaded by magic
MAGIC_RC_FILEPATH="${RUN_DIR}/magicrc"
CONTAINER_MAGIC_RC_FILEPATH="${CONTAINER_RUN_DIR}/magicrc"

OUTPUT_FILE="test_inv.spice"

cat <<EOF > $MAGIC_RC_FILEPATH
gds flatglob *pmos*
gds flatglob *nmos*
gds read $GDS
load $CELL
select top cell
extract path extfiles
extract all
ext2sim labels on
ext2sim -p extfiles
extresist tolerance 1
extresist simplify on
extresist
ext2spice lvs
ext2spice cthresh 0
ext2spice extresist on
ext2spice -p extfiles -o ${OUTPUT_FILE}
quit -noprompt
EOF

echo ">>> 4. Extracting layout using magic..."
$CMD "source ~/.bashrc; cd ${CONTAINER_RUN_DIR}; magic -dnull -noconsole -rcfile ${CONTAINER_RCFILE} < ${CONTAINER_MAGIC_RC_FILEPATH}"


echo ">>> 5. Check generated spice file"

OUTPUT_FILE_PATH=${RUN_DIR}/${OUTPUT_FILE}

if [[ -f ${OUTPUT_FILE_PATH} ]] ; then
    printf "INFO: file exists at ${OUTPUT_FILE_PATH}\t [PASS]\n"
else
    printf "ERROR: file not found\t [FAIL]\n" 1>&2
    exit -1
fi


NCAP=$(grep -E "^C" ${OUTPUT_FILE_PATH} | wc -l)
NRES=$(grep -E "^R" ${OUTPUT_FILE_PATH} | wc -l)

if [[ $NCAP -gt 0 ]]; then
    printf "INFO: extracted netlist has $NCAP parasitic capacitances\t [PASS]\n"
else
    printf "ERROR: parasitic capacitances weren't extracted\t [FAIL]\n" 1>&2
    exit -1
fi

if [[ $NRES -gt 0 ]]; then
    printf "INFO: extracted netlist has $NRES parasitic resistances \t [PASS]\n"
else
    printf "ERROR: parasitic resistors weren't extracted\t [FAIL]\n" 1>&2
    exit -1
fi

echo ""
echo "INFO: Congratulations! all validations passed!"
echo ""

docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}
exit 0
