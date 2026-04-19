if {$::tcl_platform(platform) ne "windows"} {
    return
}

package ifneeded twapi_base 5.0.2 \
    [list apply [list {dir} {
        package require platform
        set packageVer [string map {. {}} 5.0.2]
        if {[package vsatisfies [package require Tcl] 9]} {
            set baseDllName "tcl9twapi502.a"
        } else {
            set baseDllName "twapi502.a"
        }
        set package "twapi"
        set package_ns ::$package
        namespace eval $package_ns {}
        set package_init_name [string totitle $package]

        # Try to load from current directory and if that fails try from
        # platform-specific directories. Note on failure to load when the DLL
        # exists, we do not try to load from other locations as twapi modules
        # may have been partially set up.

        set dllFound false
        foreach platform [linsert [::platform::patterns [platform::identify]] 0 .] {
            if {$platform eq "tcl"} continue
            set path [file join $dir $platform $baseDllName]
            if {[file exists $path]} {
                uplevel #0 [list load $path $package_init_name]
                set dllFound true
                break
            }
        }

        if {!$dllFound} {
			# The next line was commented out since freeWrap statically links in the TWAPI extension.
            #error "Could not locate TWAPI dll."
        }

        # Load was successful
        set ${package_ns}::dllPath [file normalize $path]
        set ${package_ns}::packageDir $dir
        source [file join $dir twapi.tcl]
        package provide twapi_base 5.0.2
}] $dir]

set __twapimods {
    com
    msi
    power
    printer
    synch
    security
    account
    apputil
    clipboard
    console
    crypto
    device
    etw
    eventlog
    mstask
    multimedia
    namedpipe
    network
    nls
    os
    pdh
    process
    rds
    registry
    resource
    service
    share
    shell
    storage
    ui
    input
    winsta
    wmi
}
foreach __twapimod $__twapimods {
    package ifneeded twapi_$__twapimod 5.0.2 \
        [list apply [list {dir mod} {
            package require twapi_base 5.0.2
            source [file join $dir $mod.tcl]
            package provide twapi_$mod 5.0.2
        }] $dir $__twapimod]
}

package ifneeded twapi 5.0.2 \
    [list apply [list {dir mods} {
        package require twapi_base 5.0.2
        foreach mod $mods {
            package require twapi_$mod 5.0.2
        }
        package provide twapi 5.0.2
    }] $dir $__twapimods]

unset __twapimod
unset __twapimods
