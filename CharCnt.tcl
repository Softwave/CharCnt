# CharCnt, a little character and word counter program
# Written in Tcl/Tk
# Features drag-and-drop and real-time char and word counting 
# (c) Softwave 
# https://s0ftwave.net/
# This program is free software. See LICENSE for details.

package require Tk

proc prependAutoPath {dir} {
    if {$dir eq ""} {
        return
    }
    set pos [lsearch -exact $::auto_path $dir]
    if {$pos >= 0} {
        set ::auto_path [lreplace $::auto_path $pos $pos]
    }
    set ::auto_path [linsert $::auto_path 0 $dir]
}

# Get TkDND 
proc initTkDnd {} {
    set scriptDir [file dirname [info script]]
    set exeDir [file dirname [info nameofexecutable]]
    if {[tk windowingsystem] eq "win32"} {
        set candidates [list \
            "/zvfs/tkdndwin" \
            "/zvfs/lib/tkdndwin" \
            [file join $scriptDir tkdndwin] \
            [file join $scriptDir lib tkdndwin] \
            [file join $exeDir tkdndwin] \
            [file join $exeDir lib tkdndwin] \
            [file join [pwd] tkdndwin] \
            [file join [pwd] lib tkdndwin] \
            "/zvfs/tkdnd" \
            "/zvfs/lib/tkdnd" \
            [file join $scriptDir tkdnd] \
            [file join $scriptDir lib tkdnd] \
            [file join $exeDir tkdnd] \
            [file join $exeDir lib tkdnd] \
            [file join [pwd] tkdnd] \
            [file join [pwd] lib tkdnd]]
    } else {
        set candidates [list \
            "/zvfs/tkdnd" \
            "/zvfs/lib/tkdnd" \
            [file join $scriptDir tkdnd] \
            [file join $scriptDir lib tkdnd] \
            [file join $exeDir tkdnd] \
            [file join $exeDir lib tkdnd] \
            [file join [pwd] tkdnd] \
            [file join [pwd] lib tkdnd]]
    }

    set seen {}
    set validDirs {}
    foreach dir $candidates {
        if {$dir eq "" || [lsearch -exact $seen $dir] >= 0} {
            continue
        }
        lappend seen $dir
        if {[file exists [file join $dir pkgIndex.tcl]]} {
            lappend validDirs $dir
        }
    }

    # Prepend so Windows/Wine candidates win over any previously discovered paths.
    foreach dir [lreverse $validDirs] {
        prependAutoPath $dir
    }

    if {![catch {package require tkdnd} loadErr]} {
        return 1
    }

    foreach dir $validDirs {
        set idx [file join $dir pkgIndex.tcl]
        if {[file exists $idx]} {
            catch {source $idx}
        }
    }

    if {![catch {package require tkdnd} loadErr]} {
        return 1
    }

    tk_messageBox -icon error -title "Library Error" \
        -message "tkdnd load failed: $loadErr\n\nSearched:\n[join $seen \n]"
    return 0
}

set ::hasTkDnd [initTkDnd]

# Fonts
set fontName "Departure Mono"
set internalFont "/zvfs/DepartureMono-Regular.ttf"
set tempFont "/tmp/DepartureMono-Regular.ttf"

if {[file exists $internalFont]} {
    if {![file exists $tempFont]} { file copy -force $internalFont $tempFont }
    set fontFile $tempFont
} else {
    set fontFile "./DepartureMono-Regular.ttf"
}

# Do it a specific way on Windows
if {$tcl_platform(platform) eq "windows"} {
    catch {
        package require twapi
        twapi::add_font_resource [file normalize $fontFile]
    }
}

font create MyCustomStyle -family $fontName -size 11
font create MyCustomBold  -family $fontName -size 11 -weight bold


# Window setup
wm title . "CharCnt"
wm geometry . 272x312
wm attributes . -topmost 1 ;# Keep it on top
. configure -bg "#eeeeee" -padx 10 -pady 10

# Actual brains of the thing
proc updateCounts {args} {
    set content [.txt get 1.0 end-1c]
    set charCount [string length $content]
    set wordCount [llength [regexp -all -inline {\S+} $content]]
    .status configure -text "Words: $wordCount  |  Chars: $charCount"
}

proc urlDecodePath {value} {
    set out ""
    set i 0
    set n [string length $value]
    while {$i < $n} {
        set ch [string index $value $i]
        if {$ch eq "%" && $i + 2 < $n} {
            set hex [string range $value [expr {$i + 1}] [expr {$i + 2}]]
            if {[string is xdigit -strict $hex]} {
                append out [binary format H2 $hex]
                incr i 3
                continue
            }
        }
        if {$ch eq "+"} {
            append out " "
        } else {
            append out $ch
        }
        incr i
    }
    return $out
}

proc dropItemToPath {item} {
    set value [string trim $item "{}"]
    if {[string match "file://*" $value]} {
        set host ""
        set uriPath ""
        if {[regexp -nocase {^file://([^/]*)(/.*)?$} $value -> host uriPath]} {
            if {$uriPath eq ""} {
                set uriPath "/"
            }
            if {$host ne "" && [string tolower $host] ne "localhost"} {
                set value "//$host$uriPath"
            } else {
                set value $uriPath
            }
        } else {
            set value [string range $value 7 end]
        }
    }

    set value [urlDecodePath $value]

    if {[tk windowingsystem] eq "win32" && [regexp {^/([A-Za-z]:/.*)$} $value -> drivePath]} {
        set value $drivePath
    }

    set normalized $value
    catch {set normalized [file normalize $value]}
    return $normalized
}

proc splitDropItems {data} {
    set payload [string trim $data]
    if {$payload eq ""} {
        return {}
    }
    if {![catch {llength $payload}]} {
        return [lrange $payload 0 end]
    }
    return [list $payload]
}

proc handleDrop {data} {
    set droppedItems [splitDropItems $data]

    foreach item $droppedItems {
        set filename [dropItemToPath $item]

        if {[file exists $filename] && [file readable $filename]} {
            if {[catch {
                set chan [open $filename r]
                fconfigure $chan -encoding utf-8
                set content [read $chan]
                close $chan

                .txt delete 1.0 end
                .txt insert 1.0 $content
                updateCounts
            } err]} {
                puts "Error reading file: $err"
            }
            .txt configure -bg "#ededed"
            return "copy"
        }
    }

    # Nice, we've accomplished our drop we can reset the bg colour
    .txt configure -bg "#ededed"
    return "copy"
}

proc handleTextDrop {data} {
    .txt insert insert $data
    updateCounts
    .txt configure -bg "#ededed"
    return "copy"
}

proc handleAnyDrop {data} {
    if {[catch {
        set payload [string trim $data]

        # Sometimes it rejects it the very first time so we do a fallback.
        if {$payload eq ""} {
            catch {set payload [selection get -selection XdndSelection]}
        }

        if {$payload eq ""} {
            .txt configure -bg "#ededed"
            return "copy"
        }

        foreach item [splitDropItems $payload] {
            set candidate [dropItemToPath $item]
            if {[file exists $candidate] && [file readable $candidate]} {
                return [handleDrop $payload]
            }
        }

        return [handleTextDrop $payload]
    } err]} {
        puts "Drop handler error: $err"
        .txt configure -bg "#ededed"
        return "copy"
    }
}


# Make GUI
label .status -text "Words: 0 | Chars: 0" -font MyCustomBold -bg "#c4d3c3" -fg "#333333" -pady 4
text .txt -font MyCustomStyle -bg "#ededed" -fg "#333333" \
    -highlightthickness 1 -highlightcolor "#c4d3c3" -highlightbackground "#eeeeee" \
    -insertbackground "#333333" -selectbackground "#c4d3c3" -selectforeground "#333333" \
    -inactiveselectbackground "#c4d3c3" -exportselection 0 -padx 10 -pady 10 -undo true

pack .status -side bottom -fill x -pady {5 0}
pack .txt -expand yes -fill both

if {$::hasTkDnd && [info commands ::tkdnd::drop_target] ne ""} {
    tkdnd::drop_target register .txt {DND_Files DND_Text}
    bind .txt <<DropEnter>> { .txt configure -bg "#d5e0d4"; return copy }
    bind .txt <<DropPosition>> { return copy }
    bind .txt <<DropLeave>> { .txt configure -bg "#ededed" }
    bind .txt <<Drop>> {handleAnyDrop %D}
}

# Key bindings
bind .txt <KeyRelease> updateCounts
bind .txt <Control-a> { %W tag add sel 1.0 end; break }
bind .txt <<Paste>> { after idle updateCounts }
bind .txt <<Cut>>   { after idle updateCounts }


# Right click menu
menu .m -tearoff 0 -bg "#333333" -fg "#ffffff" \
    -activebackground "#c4d3c3" -activeforeground "#333333" \
    -font MyCustomStyle
.m add command -label "Copy"  -command {event generate .txt <<Copy>>}
.m add command -label "Paste" -command {event generate .txt <<Paste>>}
.m add command -label "Cut"   -command {event generate .txt <<Cut>>}
.m add separator
.m add command -label "Clear" -command {.txt delete 1.0 end; updateCounts}
.m add separator
.m add command -label "About" -command showAbout

proc showMenu {x y} { tk_popup .m $x $y }
bind .txt <Button-3> {showMenu %X %Y}

# About menu
proc showAbout {} {
    if {[winfo exists .about]} { focus .about; return }
    toplevel .about
    wm title .about "About"
    set aboutW 320
    set aboutH 150
    set x [expr {[winfo rootx .] + 24}]
    set y [expr {[winfo rooty .] + 24}]
    wm geometry .about "${aboutW}x${aboutH}+${x}+${y}"
    wm resizable .about 0 0
    wm transient .about .
    .about configure -bg "#eeeeee" -padx 15 -pady 15

    label .about.t -text "CharCnt" -font MyCustomBold -bg "#eeeeee" -fg "#333333"
    label .about.d -text "Little utility program\n(c) Softwave 2026\nhttps://s0ftwave.net/" \
        -font MyCustomStyle -bg "#eeeeee" -fg "#666666" -justify center
    button .about.b -text "Hooray!" -font MyCustomStyle -command {destroy .about} \
        -bg "#c4d3c3" -fg "#333333" -padx 10 -pady 5 -activebackground "#adbfab" -activeforeground "#333333"

    pack .about.t .about.d .about.b -pady 2
}

updateCounts
