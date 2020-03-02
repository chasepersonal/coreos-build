#######################################################
# Author: Chase Weyer
# Created: 3/1/2020
# Last Updated: 3/1/2020
# Scope:
# This script will build a CoreOS iso image embeded
# with a custom ignition file.
# It will also transpile the file from a .fcc file
# to a .ign file that CoreOS can read.
# It will use multiple calls to podman and CoreOS
# containers so that it can create the iso.
########################################################

# Check that fcos.fcc file exists. Otherwise, exit script
# If it does exist, run through the steps to perform the build

if [[ ! -f "fcos.fcc" ]];
then
    echo "Error! .fcc file does not exist";
    exit 1;
else
    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < fcos.fcc > fcos.ign;
    docker run -i quay.io/coreos/coreos-installer:release download -f iso -d > output
    CONTAINER=$(docker ps -a -q);
    # Grab ISO image name using the output from the download
    # WIll use the coreos conventions to find the appropriate file name
    ISO=$(sed 's#^./fedora-coreos*#fedora-coreos#g' output | grep fedora-coreos)
    docker cp fcos.ign ${CONTAINER}:/fcos.ign;
    # Commit container as a new image so it retains all the new files
    docker commit ${CONTAINER} coreos-installer-modified;
    # Remove the non-running containers as they are not needed
    docker rm $(docker ps -a -q);
    docker run -i coreos-installer-modified iso embed -c fcos.ign ${ISO};
    # Commit container as a new image one final time
    # This will be needed for the embed check
    docker commit ${CONTAINER} coreos-installer-final;
    # Remove the non-running containers as they are not needed
    docker rm $(docker ps -a -q);
    docker run -i coreos-installer-final iso show ${ISO} > embed-output

    if [[ $(cat embed-output) == "Error: No embedded Ignition config." ]];
    then
        echo "Embed of ignition file failed. Terminating script";
        exit 1;
    fi

    # Create a directory for the iso if one does not exist
    mkdir -p coreos-build
    # Export iso from final cotainer
    docker cp ${CONTAINER}:/${ISO} /coreos-build/${ISO}
fi



