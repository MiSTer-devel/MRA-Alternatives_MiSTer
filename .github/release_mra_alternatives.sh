#!/bin/bash

set -euo pipefail

MRA_DIR="."
MRA_ALTERNATIVES_DIR="_alternatives"
RELEASES_PATH="releases"

export GIT_MERGE_AUTOEDIT=no
git config user.email "theypsilon@gmail.com"
git config user.name "The CI/CD Bot"

echo "Checking for changed MRA-Alternatives..."
echo

ARTIFACT_NAME="MRA-Alternatives"
LATEST_RELEASE_FILE=$(cd "${RELEASES_PATH}"/ ; git ls-files -z | xargs -0 -n1 -I{} -- git log -1 --format="%ai {}" {} | grep "${ARTIFACT_NAME}" | sort | tail -n1 | awk '{ print substr($0, index($0,$4)) }')

echo "Latest release: ${LATEST_RELEASE_FILE}"
echo

UNZIP_DIR=$(mktemp -d)
LATEST_RELEASE_DIR="${UNZIP_DIR}/${MRA_ALTERNATIVES_DIR}"

unzip "${RELEASES_PATH}/${LATEST_RELEASE_FILE}" -d "${UNZIP_DIR}"

LATEST_RELEASE_FINDS=$(mktemp)
MRA_ALTERNATIVES_FINDS=$(mktemp)

echo
pushd "${LATEST_RELEASE_DIR}" 
find . -iname '*.mra' > "${LATEST_RELEASE_FINDS}"
popd
pushd "${MRA_ALTERNATIVES_DIR}"
find . -iname '*.mra' > "${MRA_ALTERNATIVES_FINDS}"
popd

LATEST_RELEASE_MRA_QTY=$(cat "${LATEST_RELEASE_FINDS}" | wc -l | awk '{print $1}')
CURRENT_FOLDER_MRA_QTY=$(cat "${MRA_ALTERNATIVES_FINDS}" | wc -l | awk '{print $1}')

echo
echo "Looking for differences in MRA files..."
echo

DIFFERENCES_FOUND="false"
if ! git diff --exit-code "${LATEST_RELEASE_FINDS}" "${MRA_ALTERNATIVES_FINDS}" ; then
    DIFFERENCES_FOUND="true"

    echo
    echo "Found differences"
    echo "Latest release #MRAs: ${LATEST_RELEASE_MRA_QTY}"
    echo "Current folder #MRAs: ${CURRENT_FOLDER_MRA_QTY}"
else
    CHANGED_FILES=()
    while IFS="" read -r line || [ -n "${line}" ]
    do
        LINA_MRA_FILE="${line:2}"
        LINE_MRA_PATH_1="${MRA_ALTERNATIVES_DIR}/${LINA_MRA_FILE}"
        LINE_MRA_PATH_2="${LATEST_RELEASE_DIR}/${LINA_MRA_FILE}"
        if [ ! -f "${LINE_MRA_PATH_2}" ] ; then echo "UNEXPEXTED: File ${LINE_MRA_PATH_2} doesn't exist!" ; exit 1 ; fi
        if [ ! -f "${LINE_MRA_PATH_1}" ] ; then echo "UNEXPEXTED: File ${LINE_MRA_PATH_1} doesn't exist!" ; exit 1 ; fi

        if ! git diff --exit-code --ignore-space-at-eol "${LINE_MRA_PATH_1}" "${LINE_MRA_PATH_2}" ; then
            echo
            echo "Found differences"
            echo
            CHANGED_FILES+=( "${LINA_MRA_FILE}" )
        fi
    done < "${LATEST_RELEASE_FINDS}"

    if [ ${#CHANGED_FILES[@]} -ge 1 ] ; then
        DIFFERENCES_FOUND="true"
        echo "Following files have changes: "
        for changed_file in "${CHANGED_FILES[@]}"
        do
            echo "${changed_file}"
        done
    fi
fi

if [[ "${DIFFERENCES_FOUND}" == "true" ]] ; then
    echo
    echo "Publishing new release with ${CURRENT_FOLDER_MRA_QTY} MRAs."

    pushd ${MRA_DIR} > /dev/null

    TODAYS_MRA_ALTERNATIVES_FILE="MRA-Alternatives_$(date +"%Y%m%d").zip"

    echo
    echo "Creating ZIP file: ${TODAYS_MRA_ALTERNATIVES_FILE}"
    zip -9 -r ${TODAYS_MRA_ALTERNATIVES_FILE} ${MRA_ALTERNATIVES_DIR}

    popd > /dev/null

    echo
    echo "Moving '${MRA_DIR}/${TODAYS_MRA_ALTERNATIVES_FILE}' to '${RELEASES_PATH}'."
    mv "${MRA_DIR}/${TODAYS_MRA_ALTERNATIVES_FILE}" "${RELEASES_PATH}/"

    echo
    echo "Pushing changes to origin:"
    git add "${RELEASES_PATH}"
    git commit -m "BOT: Releasing ${TODAYS_MRA_ALTERNATIVES_FILE}." -m "Because new changes have been detected."
    git push origin master
else
    echo "Found none."
fi

rm -rf "${UNZIP_DIR}"
rm "${LATEST_RELEASE_FINDS}"
rm "${MRA_ALTERNATIVES_FINDS}"