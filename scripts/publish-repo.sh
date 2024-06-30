#!/usr/local/bin/bash

original_dir=$(pwd)

# Get build name and number from pubspec
file=$(cat $original_dir/pubspec.yaml)
BUILD_NAME=$(echo $file | sed -ne 's/[^0-9]*\(\([0-9]\.\)\{0,4\}[0-9][^.]\).*/\1/p')
BUILD_NUMBER=$(git rev-list HEAD --count)

# Clone public repo
cd scripts
if test -d "cloneRepo"; then
    rm -rf cloneRepo
fi

mkdir cloneRepo
cd cloneRepo
git clone git@github.com:go-acoustic/acoustic_tealeaf.git
cd acoustic_tealeaf
git fetch 
git checkout main
git pull
git_dir=$(pwd)
cd $original_dir

# Copy files and directory to the public repo
for f in $original_dir/*; do
    # Directories to skip
   if [[ $f  == *"scripts" || $f  == *"flutter_patches" || $f  == *"connect_aop" || $f  == *"connect_aop" || $f  == *"test" ]]; then
        continue
   fi
# Directory
    if [[ -d $f ]]; then

        dir_name="$(basename $f)"
    
        if test -d "$git_dir/$dir_name"; then
            rm -rf $git_dir/$dir_name
        fi
        echo $f
        
        # Copy to public repo
        rsync -avzh $original_dir/$dir_name/ $git_dir/$dir_name/

    # File
    elif [[ -f $f ]]; then
        file_name="$(basename $f)"

        if test -f "$git_dir/$file_name"; then
            rm $git_dir/$file_name
        fi
        echo $original_dir/$file_name
        cp $original_dir/$file_name $git_dir
    fi
done

# Delete public repo directorys to add specified files
if test -d "$git_dir/flutter_patches"; then
    rm -rf "$git_dir/flutter_patches"
    mkdir "$git_dir/flutter_patches"
fi

if test -d "$git_dir/connect_aop"; then
    rm -rf "$git_dir/connect_aop"
    mkdir "$git_dir/connect_aop"
    cd "$git_dir/connect_aop"
    mkdir flutter_frontend_server
    cd $git_dir
fi

if test -d "$git_dir/scripts"; then
    rm -rf "$git_dir/scripts"
fi

if test -d "$git_dir/test"; then
    rm -rf "$git_dir/test"
fi

if test -d "$git_dir/test-results"; then
    rm -rf "$git_dir/test-results"
fi

if test -d "$git_dir/example/integration_test"; then
    rm -rf "$git_dir/example/integration_test"
fi

if test -d "$git_dir/example/test"; then
    rm -rf "$git_dir/example/test"
fi

if test -f "$git_dir/Jenkinsfile"; then
    rm "$git_dir/Jenkinsfile"
fi



# Copy flutter zip patches
for zipFile in "$original_dir/flutter_patches/connect_flutter_patch_"* 
do
 echo "Copying $(basename $zipFile)"
 cp $zipFile $git_dir/flutter_patches/
done


# Copy frontend_server.dart.snapshot
cd $original_dir/connect_aop/flutter_frontend_server
search_dir=$(pwd)
for aop in "$search_dir"/*
do  
    if [[ $aop == *"frontend_server.dart.snapshot"* ]]; then
        cp $aop $git_dir/connect_aop/flutter_frontend_server/
    fi
done

# Push changes to public repo
cd $git_dir

git add --all
git status
git commit -a -m "${BUILD_NAME} ${BUILD_NUMBER}"
git push