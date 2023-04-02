# Imports
import osproc
import strformat
import argparse
import system
import tables
import strutils
import sequtils
import json

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
            var initDictonary = {"router": "$router.nim", "mainComponent": "components/mainComponent.nim", "notFound": "components/notFound.nim", "html": "../static/$container.html", "nimble": "../package.nimble", "manifest": "../static/$manifest.json"}.toTable
            for tmpl, file in initDictonary:
                createStarterFiles(tmpl, file)
            copyFile(fmt"{installDirectory}/templates/icon.jpg", "static/$icon.jpg")
            
            echo("A new Karax project was created.")
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
            
            # Creates manifest
            var manifest = "static/$manifest.json"
            var templateManifest = fmt"{installDirectory}/templates/manifest.txt"
            var destManifest = "build/manifest.json"

            if fileExists(manifest) == false:
                if fileExists(templateManifest) == true:
                    copyFile(templateManifest, manifest)
                else:
                    echo(templatesMissingError)
                    quit()
            
            copyFile(manifest, destManifest)
            var manifestRoot = parseJson(readFile(manifest))
            var themeColor = manifestRoot["theme_color"].getStr()
            var htmlDescription = manifestRoot["description"].getStr()
            var htmlTitle = manifestRoot["name"].getStr()

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
                        echo(execShellCmd(fmt"pwa-asset-generator {icon} {destAssets} -i {destHtmlFile} -m {destManifest} -f"))
                        removeFile(icon)
                    of pcDir:
                        copyDir(path, path.replace("static/", "build/"))
                    of pcLinkToFile:
                        echo("")
                    of pcLinkToDir:
                        echo("")
            
            writeFile(destHtmlFile, readFile(destHtmlFile).replace("</head>", readFile(templateHtmlBoilerplate).replace("VAR_THEME_COLOR", themeColor).replace("VAR_DESCRIPTION", htmlDescription).replace("VAR_TITLE", htmlTitle)))
            
            # Bundles the main JavaScript
            echo(execShellCmd("webpack ./build/app.js"))
            moveFile("dist/main.js", "build/app.js")
            removeDir("dist")

            # Copies public files
            copyDir("static", buildDirectory)
            removeFile("build/$container.html")
            removeFile("build/$manifest.json")
            proc removeIfExists(file: string) =
                if fileExists(file):
                    removeFile(file)
            removeIfExists("""build/$icon.png""")
            removeIfExists("""build/$icon.ico""")
            removeIfExists("""build/$icon.webp""")
            removeIfExists("""build/$icon.jpg""")
            removeIfExists("""build/$icon.jpeg""")

            # Removes tmp and comunicates success
            removeDir("tmp")
            echo("The project was built successfully.")
            quit()


p.run

echo("""No option selected. To init a project use "init", to compile it use "compile" and to run it use "run"""")