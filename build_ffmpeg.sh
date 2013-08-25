#!/bin/bash

os=""
cmake_env=""
linking=""
macosx_arch="x86_64" # ppc or i386 or x86_64
source_dir=""
build_dir=""
macosx_sdk=""
has_vda=0
vcpp=0
jobsCount=4 # how many compilations at a time
full_decoders_list=""

function check_err()
{
	if [ $? -ne 0 ]
	  then
	    echo "*** an error occured, aborting.";
	    exit 1;
	fi
}

function build_ffmpeg()
{
	# Using dynamically linked libraries for MSVC and Linux,
	# and static libs for Codeblocks (Windows) and Mac OS X
	if [ "$vcpp" == "1" ] || [ "$os" == "linux" ]
	  then
		args="$args --enable-shared --disable-static"
	fi
	
    # build ffmpeg
    if test -d "${source_dir}/deps/ffmpeg"
      then
        configure_flags="";
        
        for codec in $full_decoders_list
          do
            configure_flags="$configure_flags --enable-decoder=$codec"
        done
        
        if [ "$os" == "macosx" ]
          then
          	if [ "$macosx_sdk" != "" ]
          	  then
          	    os_flags="$os_flags --sysroot=$macosx_sdk"
          	fi
          	
          	if [ "$has_vda" == "0" ]
          	  then
          	    os_flags="$os_flags --disable-vda"
          	fi
          		
        	#os_flags="$os_flags --cc=\"gcc -arch $macosx_arch\" --arch=$macosx_arch --target-os=darwin --enable-cross-compile --host-cflags=\"-arch $macosx_arch\" --host-ldflags=\"-arch $macosx_arch\""
        fi
		
		if [ "$os" == "windows" ]
		  then
			os_flags="--enable-memalign-hack --enable-w32threads"
		fi
	
		args="$args --disable-ffmpeg --disable-ffplay --disable-ffprobe --disable-ffserver --disable-doc --disable-encoders --disable-decoders --disable-muxers --disable-yasm $configure_flags $os_flags"
	    
	
		#setup VC++ env variables to find lib.exe
		if [ "$vcpp" == "1" ]
		  then
			old_path=`echo $PATH`
			export PATH="$PATH:/C/Program Files/Microsoft Visual Studio 9.0/Common7/IDE:/C/Program Files/Microsoft Visual Studio 9.0/VC/bin"
			export PATH="$PATH:/C/Program Files/Microsoft Visual Studio 10.0/Common7/IDE:/C/Program Files/Microsoft Visual Studio 10.0/VC/bin"
			export PATH="$PATH:/C/Program Files/Microsoft Visual Studio 11.0/Common7/IDE:/C/Program Files/Microsoft Visual Studio 11.0/VC/bin"
			export PATH="$PATH:/C/Program Files (x86)/Microsoft Visual Studio 9.0/Common7/IDE:/C/Program Files (x86)/Microsoft Visual Studio 9.0/VC/bin"
			export PATH="$PATH:/C/Program Files (x86)/Microsoft Visual Studio 10.0/Common7/IDE:/C/Program Files (x86)/Microsoft Visual Studio 10.0/VC/bin"
			export PATH="$PATH:/C/Program Files (x86)/Microsoft Visual Studio 11.0/Common7/IDE:/C/Program Files (x86)/Microsoft Visual Studio 11.0/VC/bin"
		fi
		
        chmod u+x "${source_dir}/deps/ffmpeg/configure" "${source_dir}/deps/ffmpeg/version.sh" "${source_dir}/deps/ffmpeg/doc/texi2pod.pl"
        mkdir -p "${build_dir}/FFmpeg-objects"
        cd "${build_dir}/FFmpeg-objects"

        echo "${source_dir}/deps/ffmpeg/configure $args"
        { echo "$args" | xargs "${source_dir}/deps/ffmpeg/configure"; }
        check_err
        make clean
        check_err
        make --jobs=$jobsCount
        check_err
        
        if [ "$vcpp" == "1" ]
          then
			export PATH="$old_path"
		fi
        
        ffmpeg_sources_dir="${source_dir}/deps/ffmpeg"
        ffmpeg_objects_dir="${build_dir}/FFmpeg-objects"
        ffmpeg_binaries_dir="${build_dir}/FFmpeg-binaries"

		mkdir -p "${ffmpeg_binaries_dir}"
		rm -f "${ffmpeg_binaries_dir}/*"
	    
		echo "Copying libraries into ffmpeg-build"
		if [ "$vcpp" == "1" ]
		  then
			cp -v `find "${ffmpeg_objects_dir}" -name "*.lib"` "${ffmpeg_binaries_dir}"
			check_err
			cp -v `find "${ffmpeg_objects_dir}" -name "*.dll"` "${ffmpeg_binaries_dir}"
			check_err
		else
			if [ "$os" == "linux" ]
			  then
			    cp -vfl `find "${ffmpeg_objects_dir}" -name "*.so*"` "${ffmpeg_binaries_dir}"
			else
				cp -v `find "${ffmpeg_objects_dir}" -name "*.a"` "${ffmpeg_binaries_dir}"
			fi
			check_err
		fi
		
        cd ${source_dir}
    else
    	echo "Missing ffmpeg sources directory at ${source_dir}/deps/ffmpeg. Aborting."
    	exit 1
    fi
	
	echo "Built ffmpeg"
}


function main()
{
	command_args="linux|windows|macosx novs|vs notosx|i386|x86_64 decoders_list"
	# want help?
	if [ "$1" == "-h" ] ||
	   [ "$1" == "--help" ]
	   then
	     echo "Usage: $0 $command_args"
	else
		if ([ "$1" != "linux" ] && [ "$1" != "windows" ] && [ "$1" != "macosx" ]) ||
			([ "$2" != "novs" ] && [ "$2" != "vs" ]) ||
			([ "$3" != "notosx" ] && [ "$3" != "i386" ] && [ "$3" != "x86_64" ])
		  then
		    echo "Usage: $0 $command_args"
		    echo "Got $*"
		else
			# do build process
			os="$1"
			
			if [ "$2" == "vs" ]
			  then
				vcpp="1"
			fi
			
			macosx_arch="$3"
			source_dir=`cat SourceDir.var`
			build_dir=`cat BuildDir.var`

			shift
			shift
			shift
			full_decoders_list="$*"
			
			echo "Build directory : ${build_dir}"
			echo "OS              : $os"
			echo "Visual Studio   : $vcpp"
			echo "OS X arch       : $macosx_arch"
			echo "Decoders        : $full_decoders_list"
			
			# build.. well it's written
			build_ffmpeg $*
		fi
	fi
}

main $*

