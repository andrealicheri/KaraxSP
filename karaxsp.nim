# Imports
import osproc
import strformat
import argparse
import system
import tables
import strutils

# Defines errors
var templatesMissingError: string = "One or more templates are missing. Check you have installed KaraxSP correctly."
var dataDirDoesNotExistsError: string = "The KaraxSP directory doesn't exist. Check you have installed KaraxSP correctly."
var initError: string = "A project already exists in this directory."


# Checks OS
when defined windows:
    var userenv = getEnv("USERPROFILE")
    var installDirectory = fmt"{userenv}/karaxsp"
elif defined linux:
    var userenv = getEnv("HOME")
    var installDirectory = fmt"{userenv}/karaxsp"
else:
    # I'm not drunk. I did not allocate the error string here just for fun. The compiler would throw a warning if I didn't. 
    var platformNotSupportedError: string = "This OS is not supported. Please re-compile this build for Windows or for Linux." 
    echo(platformNotSupportedError)
    quit()

# Checks that program data is not corrupted
if dirExists(installDirectory) == false:
    echo(dataDirDoesNotExistsError)
    quit()

let p = newParser():

    # Initializes project
    command("init"):
        run:
            # Create source folder and the components folder
            if dirExists("src") == false:
                createDir("src")
                createDir("src/components")
            
            # If a project already exists, throw an error
            else:
                echo(initError)
                quit()
            
            # Defines how to create the starter files
            proc createStarterFiles(tmpl: string, file: string) =
                var filePath = fmt"src/{file}"
                var templatePath = fmt"{installDirectory}/templates/{tmpl}.txt"
                var templateContent = readFile(templatePath)
                if fileExists(templatePath) == false:
                    echo(templatesMissingError)
                    quit()
                if fileExists(filePath) == false:
                    writeFile(filePath, templateContent)
            
            # Defines and creates the starter files
            var initDictonary = {"router": "$router.nim", "mainComponent": "components/mainComponent.nim", "notFound": "components/notFound.nim"}.toTable
            for tmpl, file in initDictonary:
                createStarterFiles(tmpl, file)

    # Builds and run project
    command("compile"):
        run:
            var buildDirectory: string = "build"
            proc ephemeralDirectory(directory: string) =
                if dirExists(directory) == false:
                    createDir(directory)
                else:
                    removeDir(directory)
                    createDir(directory)
        
            ephemeralDirectory(buildDirectory)

            copyDir("src/", "tmp/")
    
            var tempRouter = "tmp/tempRouter.nim"
            writeFile(tempRouter, readFile("tmp/$router.nim"))
            let compile = execCmd(fmt"nim js {tempRouter}")
            echo(compile)
            moveFile(tempRouter, "build/app.js")
            removeDir("tmp")

p.run