# Imports
import osproc
import strformat
import argparse
import system
import strutils
echo("KaraxSP -- easy way to deal with Karax")
# Defines errors
var templatesMissingError: string = "One or more templates are missing. Check you have installed KaraxSP correctly."
var dataDirDoesNotExistsError: string = "The KaraxSP directory doesn't exist. Check you have installed KaraxSP correctly."


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

var buildDirectory: string = "build"
proc ephemeralDirectory(directory: string) =
    if dirExists(directory) == false:
        createDir(directory)
    else:
        removeDir(directory)
        createDir(directory)
        
ephemeralDirectory(buildDirectory)

copyDir("src/", "tmp/")

# Creates actual Karax bundle AND service worker
var tempRouter = "tmp/tempRouter.nim"
var jsOutput = "tmp/tempRouter.js"
var jsProd = "build/app.js"
writeFile(tempRouter, readFile("tmp/$router.nim"))
let compile = execCmd(fmt"nim js {tempRouter}")
echo(compile)
copyFile(jsOutput, jsProd)
            
var destHtmlFile = "build/index.html"
var staticHtmlContainer = "static/$container.html"
var templateHtmlContainer = fmt"{installDirectory}/templates/html.txt"
var templateServiceWorker = fmt"{installDirectory}/templates/sw.txt"
var templateHtmlBoilerplate = fmt"{installDirectory}/templates/htmlboilerplate.txt"
var serviceWorkerDest = "build/sw.js"
copyFile(templateServiceWorker, serviceWorkerDest)

# Creates HTML container
if fileExists(staticHtmlContainer) == false:
    if fileExists(templateHtmlContainer) == true:
        copyFile(templateHtmlContainer, staticHtmlContainer)
    else:
        echo(templatesMissingError)
        quit()
            
copyFile(staticHtmlContainer, destHtmlFile)
            
# Spawn assets
for kind, path in walkDir("static/"):
    # I know, this implementation should put me to death. However I have not enought time to work on a clean implementation (similar to the one in deprecated/)
    if path == """static\$icon.jpg""" or path == """static\$icon.png""" or path == """static\$icon.webp""" or path == """static\$icon.jpeg""" or path == """static\$icon.ico""":
        case kind:
        of pcFile:
            var icon = path.replace("static/", "tmp/").replace("$", "")
            var destAssets = "build/assets"
            copyFile(path, icon)
            if dirExists(destAssets):
                createDir(destAssets)
            echo(execShellCmd(fmt"pwa-asset-generator {icon} {destAssets} -i {destHtmlFile}"))
            removeFile(icon)
        of pcDir:
            copyDir(path, path.replace("static/", "build/"))
        of pcLinkToFile:
            echo("")
        of pcLinkToDir:
            echo("")
            
writeFile(destHtmlFile, readFile(destHtmlFile).replace("</head>", readFile(templateHtmlBoilerplate)))
            
# Copies public files
var publicDir = "static/public"
copyDir(publicDir, buildDirectory)
removeDir("tmp")
echo("The project was built successfully.")
quit()