#######################################################
# Author: Chase Weyer
# Created: 3/1/2020
# Last Updated: 3/1/2020
# Scope:
# This script will build a CoreOS iso image embeded
# with a custom ignition file.
# It will also transpile the file from a .fcc file
# to a .ign file that CoreOS can read.
# It will use multiple calls to docker and CoreOS
# containers so that it can create the iso.
########################################################

# Check that fcos.fcc file exists. Otherwise, exit script
# If it does exist, run through the steps to perform the build
function complete_message {
    if [ $? -eq 0 ];
    then
        echo "DONE!"
    else
        echo "ERROR!"
    fi
}


if [[ ! -f "fcos.fcc" ]];
then
    echo "Error! .fcc file does not exist";
    exit 1;
else
    echo "** Convert .fcc file to .ign file **"
    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < fcos.fcc > fcos.ign;
    complete_message
    echo "** Download newest CoreOS iso **"
    docker run -i quay.io/coreos/coreos-installer:release download -f iso -d > output
    complete_message
    # Grab ISO image name using the output from the download
    # WIll use the coreos conventions to find the appropriate file name
    echo "** Gather iso information and copy .ign to CoreOS container **"
    ISO=$(sed 's#^./fedora-coreos*#fedora-coreos#g' output | grep fedora-coreos)
    docker cp fcos.ign $(docker ps -a -q):/fcos.ign;
    complete_message
    # Commit container as a new image so it retains all the new files
    echo "** Commit new image from CoreOS container with iso and .ign file **"
    docker commit $(docker ps -a -q) coreos-installer-modified;
    complete_message
    # Remove the non-running containers as they are not needed
    echo "** Remove old container and run new CoreOS image to embed .ign within the downloaded ISO **"
    docker rm $(docker ps -a -q);
    docker run -i coreos-installer-modified iso embed -c fcos.ign $ISO;
    complete_message
    # Commit container as a new image one final time
    # This will be needed for the embed check
    echo "** Commit new image from CoreOS container that has embeded ISO **"
    docker commit $(docker ps -a -q) coreos-installer-final;
    complete_message
    # Remove the non-running containers as they are not needed
    echo "** Remove old container and run final container with embeded ISO to confirm ISO was properly embeded **"
    docker rm $(docker ps -a -q);
    docker run -i coreos-installer-final iso show $ISO > embed-output

    if [[ $(cat embed-output) == "Error: No embedded Ignition config." ]];
    then
        echo "Embed of ignition file failed. Terminating script";
        exit 1;
    else
        complete_message
    fi

    echo "** Build CoreOS s3 folder and move iso from final container to the new folder **"
    # Create a directory for the iso if one does not exist
    mkdir -p coreos-build-single
    # Export iso from final cotainer
    docker cp $(docker ps -a -q):/$ISO coreos-build-single/$ISO
    complete_message
    echo "** Remove final container and images related to build"
    docker rm $(docker ps -a -q);
    docker rmi coreos-installer-modified;
    docker rmi coreos-installer-final
    complete_message
fi



