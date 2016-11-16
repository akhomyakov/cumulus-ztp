#!/bin/bash
# Make sure that CumulusConfigs and Images folders are present. This should be rudimentary test to check if we are in the git project folder.
echo "Testing that we are in the project folder"
if [ ! -d ./CumulusConfigs -o ! -d ./Images ]
    then
        echo "Looks like one of the required folders is missing. Exiting script...";
        echo "Make sure CumulusConfig and Images folders are present and at least one .bin CumulusLinux image is located in Images!";
        exit 1;
fi

# We will look in Images folder and not in staging. They should be identical at this point since we just copied them
options=( $(find Images -maxdepth 1 -name "cumulus-linux-3*.bin" | xargs -0) )

# Test if a single image was present in the Images folder. Exit script if none found.
if [[ $options == "" ]];
    then
        echo -e "No Cumulus Linux images found to stage.\nPlease, download the latest one and place it in the Images folder"
        exit 0
    else
        echo -e "Found at least one Cumulus Linux v.3 image! Continuing..."
fi

# Making a clean folder to stage files for making of an ISO image
echo "Creating a staging folder..."
stagedir="CumulusLinux_Staging"
mkdir $stagedir

# Cleanup function that removes the staging directory
function clean_up_dir {
    echo "Cleaning up..."
    rm -fr ./$stagedir
}

# Let's copy everything we need into the staging folder
echo "Staging files..."
cp -r ./CumulusConfigs ./$stagedir/
cp -r ./Images ./$stagedir/
cp ./cumulus-ztp* ./$stagedir/
echo -e "Environment staged!\n"

# Let's prompt for image selection to boot into
prompt="Please select image to boot into:"
PS3="$prompt "
# select will display the list of files inside $options and "Quit" as the last option.
select opt in "${options[@]}" "Quit" ; do 
    # Last option will always be exit, so we use number of entries in $options plus 1. Exit script on this choice
    if (( REPLY == 1 + ${#options[@]} )) ; then
        clean_up_dir
        exit
    # Check if option is within range, echo it back to use for confirmation and break out of 'select' cycle
    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "You picked $opt which is file $REPLY"
        break
    # If an invalid choice was made, we'll remain in the 'select' cycle until either exit or a valid choice is picked
    else
        echo "Invalid option. Try another one."
    fi
done    

# Coping image from the images directory in staging folder to the root in staging folder using $opt populated by the select routine above
echo "Making $opt the boot to image"
cp $opt ./$stagedir/onie-installer

# Let's display the result of staging the files
echo "The following will be made into an ISO image. Please confirm (y/n)"
# Ideally we want to use tree to display the content of the folder, but not everyone has it installed, so we'll test for it
which tree &> /dev/null
# If tree is installed the command above will exit with exit code "0"
if [ "$?" == "0" ]; then
        tree ./$stagedir/
    else
        echo "WARNING: tree utility not found. Using ls to display content"
        ls -al ./$stagedir/
    fi
# after showing the user content of the stage folder let's ask if the user wishes to continue with making of the image
prompt="Valid input is either 1 or 2: "
PS3="$prompt "
# Display two choices: y and Abort
select opt in "y" "Abort"; do
    # If "Abort" (choice 2) is picked, exit out of the script
    if (( REPLY == 2 )) ; then
        clean_up_dir
        exit
    # if "y" (choice 1) is picked, sleep for 5 sec just in case and break out of the 'select' routine.
    elif (( REPLY == 1 )) ; then
        echo  "You picked to proceed. Waiting 5 sec before continuing...";
	sleep 5;
	echo  "Continuing";
	break 
    # Otherwise, keep requesting valid input
    else
        echo "Invalid option. Try another one."
    fi
done

# We'd only make it to this line if REPLY selection was 1 (for y)
# Let's make the ISO now
echo "Starting making of an ISO..."
hdiutil makehybrid -iso -udf -joliet -iso-volume-name CUMULUS-ISO -udf-volume-name CUMULUS-ISO -hfs-volume-name CUMULUS-ISO -o ~/CumulusLinux-OOB.iso CumulusLinux_Staging

# Clean up after ourselves
clean_up_dir

# Display path to the ISO after it done
echo "ISO image is generated"
ls ~/CumulusLinux-OOB.iso

