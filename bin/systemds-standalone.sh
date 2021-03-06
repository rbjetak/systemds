#!/usr/bin/env bash
#-------------------------------------------------------------
#
# Copyright 2019 Graz University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#-------------------------------------------------------------


# error help print
printSimpleUsage()
{
cat << EOF
Usage: $0 <dml-filename> [arguments] [-help]
    -help     - Print detailed help message
EOF
  exit 1
}

# Script internally invokes 'java -Xmx4g -Xms4g -Xmn400m [Custom-Java-Options] -jar StandaloneSystemDS.jar -f <dml-filename> -exec singlenode -config=SystemDS-config.xml [Optional-Arguments]'

# This path can stay in *nix separator style even when using cygwin/msys.
export HADOOP_HOME=/tmp/systemds
mkdir -p $HADOOP_HOME

if [ -z "$1" ] ; then
    echo "Wrong Usage.";
    printSimpleUsage
fi

if [ ! -z $SYSTEMDS_ROOT ]; then
    PROJECT_ROOT_DIR="$SYSTEMDS_ROOT"
    echo "SYTEMDS_ROOT is set to:" $SYSTEMDS_ROOT
else
    # find the systemDS root path which contains the bin folder, the script folder and the target folder
    # tolerate path with spaces
    #
    # Paths that go to the java executable need to be Windows style in cygwin/msys.
    SCRIPT_DIR=$( dirname "$0" )
    if [ "$OSTYPE" == "win32" ] ||  [ "$OSTYPE" == "msys" ] ; then
      PROJECT_ROOT_DIR=`cygpath -w -p $( cd "${SCRIPT_DIR}/.." ; pwd -P )`
    else
      PROJECT_ROOT_DIR=$( cd "${SCRIPT_DIR}/.." ; pwd -P )
    fi
fi

if [ "$OSTYPE" == "win32" ] ||  [ "$OSTYPE" == "msys" ] ; then
  DIR_SEP=\\
  USER_DIR=`cygpath -w -p ${PWD}`
else
  DIR_SEP=/
  USER_DIR=$PWD
fi

if [ ! -f ${HADOOP_HOME}${DIR_SEP}bin ]; then
  cp -a ${PROJECT_ROOT_DIR}${DIR_SEP}target${DIR_SEP}lib${DIR_SEP}hadoop${DIR_SEP}bin ${HADOOP_HOME}
fi

BUILD_DIR=${PROJECT_ROOT_DIR}${DIR_SEP}target
HADOOP_LIB_DIR=${BUILD_DIR}${DIR_SEP}lib
DML_SCRIPT_CLASS=${BUILD_DIR}${DIR_SEP}classes${DIR_SEP}org${DIR_SEP}tugraz${DIR_SEP}sysds${DIR_SEP}api${DIR_SEP}DMLScript.class

BUILD_ERR_MSG="You must build the project before running this script."
BUILD_DIR_ERR_MSG="Could not find target directory \"${BUILD_DIR}\". ${BUILD_ERR_MSG}"
HADOOP_LIB_ERR_MSG="Could not find required libraries \"${HADOOP_LIB_DIR}/*\". ${BUILD_ERR_MSG}"
DML_SCRIPT_ERR_MSG="Could not find \"${DML_SCRIPT_CLASS}\". ${BUILD_ERR_MSG}"

# check if the project had been built and the jar files exist
if [ ! -d "${BUILD_DIR}" ];        then echo "${BUILD_DIR_ERR_MSG}";  exit 1; fi
if [ ! -d "${HADOOP_LIB_DIR}" ];   then echo "${HADOOP_LIB_ERR_MSG}"; exit 1; fi
if [ ! -f "${DML_SCRIPT_CLASS}" ]; then echo "${DML_SCRIPT_ERR_MSG}"; exit 1; fi


echo "================================================================================"

# if the present working directory is the project root or bin folder, then use the temp folder as user.dir
if [ "$USER_DIR" = "$PROJECT_ROOT_DIR" ] || [ "$USER_DIR" = "$PROJECT_ROOT_DIR/bin" ]
then
  USER_DIR=${PROJECT_ROOT_DIR}${DIR_SEP}temp
  echo "Output dir: $USER_DIR"
fi


# if the SystemDS-config.xml does not exist, create it from the template
if [ ! -f "${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}SystemDS-config.xml" ]
then
  cp "${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}SystemDS-config.xml.template" \
     "${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}SystemDS-config.xml"
  echo "... created ${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}SystemDS-config.xml"
fi

# if the log4j.properties do not exis, create them from the template
if [ ! -f "${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}log4j.properties" ]
then
  cp "${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}log4j.properties.template" \
     "${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}log4j.properties"
  echo "... created ${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}log4j.properties"
fi

#SYSTEM_DS_JAR=$( find $PROJECT_ROOT_DIR/target/system-ds-*-SNAPSHOT.jar )
SYSTEM_DS_JAR=${BUILD_DIR}${DIR_SEP}classes
# add hadoop libraries which were generated by the build to the classpath
CLASSPATH=${BUILD_DIR}${DIR_SEP}lib${DIR_SEP}*

if [ "$OSTYPE" == "win32" ] ||  [ "$OSTYPE" == "msys" ] ; then
  CLASSPATH=\"${CLASSPATH}\;${SYSTEM_DS_JAR}\"
else
  CLASSPATH=\"${CLASSPATH}\:${SYSTEM_DS_JAR}\"
fi
#echo ${CLASSPATH}

echo "================================================================================"

# Set default Java options
SYSTEMDS_DEFAULT_JAVA_OPTS="\
-Xmx8g -Xms4g -Xmn1g \
-cp $CLASSPATH \
-Dlog4j.configuration=file:'$PROJECT_ROOT_DIR${DIR_SEP}conf${DIR_SEP}log4j.properties' \
-Duser.dir='$USER_DIR'"

# Add any custom Java options set by the user at command line, overriding defaults as necessary.
if [ ! -z "${SYSTEMDS_JAVA_OPTS}" ]; then
    SYSTEMDS_DEFAULT_JAVA_OPTS+=" ${SYSTEMDS_JAVA_OPTS}"
    unset SYSTEMDS_JAVA_OPTS
fi

# Add any custom Java options set by the user in the environment variables file, overriding defaults as necessary.
if [ -f "${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}systemds-env.sh" ]; then
    . "${PROJECT_ROOT_DIR}${DIR_SEP}conf${DIR_SEP}systemds-env.sh"
    if [ ! -z "${SYSTEMDS_JAVA_OPTS}" ]; then
        SYSTEMDS_DEFAULT_JAVA_OPTS+=" ${SYSTEMDS_JAVA_OPTS}"
    fi
fi


printUsageExit()
{
CMD="\
java ${SYSTEMDS_DEFAULT_JAVA_OPTS} \
org.tugraz.sysds.api.DMLScript \
-help"
eval ${CMD}
exit 0
}

while getopts "h:f:" options; do
  case $options in
    h ) echo Warning: Help requested. Will exit after usage message
        printUsageExit
        ;;
    \? ) echo Warning: Help requested. Will exit after usage message
        printUsageExit
        ;;
    f ) #echo "Shifting args due to -f"
        shift
        ;;
    * ) echo Error: Unexpected error while processing options
  esac
done

# Peel off first argument so that $@ contains arguments to DML script
SCRIPT_FILE=$1
shift

# if the script file path was omitted, try to complete the script path
if [ ! -f "$SCRIPT_FILE" ]
then
  SCRIPT_FILE_NAME=$(basename $SCRIPT_FILE)
  SCRIPT_FILE_FOUND=$(find "$PROJECT_ROOT_DIR${DIR_SEP}scripts" -name "$SCRIPT_FILE_NAME")
  if [ ! "$SCRIPT_FILE_FOUND" ]
  then
    echo "Could not find DML script: $SCRIPT_FILE"
    printSimpleUsage
  else
    SCRIPT_FILE=$SCRIPT_FILE_FOUND
    echo "DML script: $SCRIPT_FILE"
  fi
fi


# Invoke the jar with options and arguments
CMD="\
java ${SYSTEMDS_DEFAULT_JAVA_OPTS} \
org.tugraz.sysds.api.DMLScript \
-f '$SCRIPT_FILE' \
-exec singlenode \
-config '$PROJECT_ROOT_DIR${DIR_SEP}conf${DIR_SEP}SystemDS-config.xml' \
$@"

echo "\nExecuting "${CMD} "\n"
eval ${CMD}

RETURN_CODE=$?

# if there was an error, display the full java command (in case some of the variable substitutions broke it)
if [ $RETURN_CODE -ne 0 ]
then
  echo "Failed to run SystemDS. Exit code: $RETURN_CODE"
  LF=$'\n'


  # keep empty lines above for the line breaks
  echo "  ${CMD//     /$LF      }"
fi

