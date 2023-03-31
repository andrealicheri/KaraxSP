# Imports
import osproc
import strformat
import argparse
import system
import tables
import strutils
import jester

echo("KaraxSP -- easy way to deal with Karax")
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
            proc createProjectDir(folder: string) =
                if dirExists(folder) == false:
                    createDir(folder)
                else:
                    echo(initError)
                    quit()
            
            var initFolderArray = ["src", "src/components", "static"]
            for item in initFolderArray:
                createProjectDir(item)

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
            var initDictonary = {"router": "$router.nim", "mainComponent": "components/mainComponent.nim", "notFound": "components/notFound.nim", "html": "../static/$container.html", "server": "../$server.nim"}.toTable
            for tmpl, file in initDictonary:
                createStarterFiles(tmpl, file)
            
            quit()

    # Builds project
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
            var jsOutput = "tmp/tempRouter.js"
            writeFile(tempRouter, readFile("tmp/$router.nim"))
            let compile = execCmd(fmt"nim js {tempRouter}")
            echo(compile)
            moveFile(jsOutput, "build/app.js")
            
            var destHtmlFile = "build/index.html"
            var staticHtmlContainer = "static/$container.html"
            var templateHtmlContainer = fmt"{installDirectory}/templates/html.txt"
            
            if fileExists(staticHtmlContainer) == true:
                copyFile(staticHtmlContainer, destHtmlFile)
            elif fileExists(templateHtmlContainer) == true:
                copyFile(templateHtmlContainer, staticHtmlContainer)
                copyFile(staticHtmlContainer, destHtmlFile)
            else:
                echo(templatesMissingError)
                quit()
            removeDir("tmp")
            quit()

    command("run"):
        run:
            createDir("tmp")
            var nimServer = "$server.nim"
            var templateNimServer = fmt"{installDirectory}/templates/server.txt"
            var destServer = "tmp/server.nim"
            var destExe = "tmp/server.exe"
            var sysTempDir = getTempDir()
            var sysTempServer = fmt"{sysTempDir}/server.exe"
            
            proc compileServer()=
                echo(execCmd(fmt"nim c {destServer}"))
                copyFile(destExe, sysTempServer)  

            if fileExists(nimServer) == false:
                copyFile(templateNimServer, nimServer)
            elif fileExists(templateNimServer) == false:
                echo(templatesMissingError)
                quit()
            
            copyFile(nimServer, destServer)
            compileServer()
            removeDir("tmp")
            echo(execCmd(sysTempServer))            
            quit()

p.run

echo("""No option selected. To init a project use "init", to compile it use "compile" and to run it use "run""")