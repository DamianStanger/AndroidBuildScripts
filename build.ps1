
function versionFile($file, $old, $versionNumber, $versionString){
    $new = $old -replace "\[\\d\]\+\\\.\[\\d\]\+\\\.\[\\d\]\+", $versionString
    $new = $new -replace "\[\\d\]\+", $versionNumber
    Write-Host "$file  :  $old  ->  $new" 
    
    $oldContent = Get-Content -path $file
    $newContent = $oldContent -replace $old, $new
    
    $compareResult = ([System.String]$oldContent).CompareTo(([System.String]$newContent))   
    if($compareResult -eq 0){
        Write-Host -ForegroundColor Red "Something went wrong versioning file: $file - Content did not change!!"
        exit 1;
    }
    
    Set-Content -path $file -Value $newContent
}

function setVersion($versionNumber, $versionString){

    if(-not [Regex]::IsMatch($versionNumber,"^[\d]+$"))
    {
        Write-Host -ForegroundColor Red "[number] [versionString]  :  number=[\d]+ versionString=[\d]+\.[\d]+\.[\d]+"
        exit 1;
    }
    if(-not [Regex]::IsMatch($versionString,"^[\d]+\.[\d]+\.[\d]+$"))
    {
        Write-Host -ForegroundColor Red "[number] [versionString]  :  number=[\d]+ versionString=[\d]+\.[\d]+\.[\d]+"
        exit 1;
    }    

    $file = ".\source\www\config.xml"
    $old = "version=""[\d]+\.[\d]+\.[\d]+"""
    versionFile $file $old $versionNumber $versionString

    $file = ".\source\platforms\android\AndroidManifest.xml"
    $old = "android:versionCode=""[\d]+"" android:versionName=""[\d]+\.[\d]+\.[\d]+"""
    versionFile $file $old $versionNumber $versionString

    $file = ".\source\res\xml\config.xml"
    $old = "version=""[\d]+\.[\d]+\.[\d]+"""
    versionFile $file $old $versionNumber $versionString

    #$file = ".\source\www\js\config.js"
    #$old = "var appVersionNumber = '[\d]+\.[\d]+\.[\d]+'"
    #versionFile $file $old $versionNumber $versionString
}



function create(){
    Write-Host -ForegroundColor Green "*** create ***"

    Remove-Item .\app-cordova-android -Recurse -Force -ErrorAction ignore
    if(Test-Path .\app-cordova-android){
        Remove-Item .\app-cordova-android -Recurse -Force -ErrorAction Stop    
    }

    Write-Host -ForegroundColor Green "  cordova create app-cordova-android com.myapp.app myapp"
    & cordova create app-cordova-android com.myapp.app myapp
    Set-Location .\app-cordova-android
    
    Write-Host -ForegroundColor Green "  cordova platform add android"
    & cordova platform add android
    Copy-Item ..\source\platforms\android\AndroidManifest.xml .\platforms\android\AndroidManifest.xml -Force -ErrorAction stop
    
    Write-Host -ForegroundColor Green "  cordova plugin add .."
    & cordova plugin add org.apache.cordova.device    
    & cordova plugin add org.apache.cordova.dialogs
    & cordova plugin add org.apache.cordova.network-information
    & cordova plugin add org.apache.cordova.vibration
    
    Remove-Item .\www -Recurse -Force -ErrorAction stop
    Copy-Item ..\source\www .\ -Recurse -ErrorAction Stop
    Remove-Item .\www\.idea -Recurse -Force -ErrorAction ignore
    Remove-Item .\www\spec -Recurse -Force -ErrorAction stop
    Remove-Item .\www\spec.html -Recurse -Force -ErrorAction stop

    Remove-Item .\platforms\android\res -Recurse -Force -ErrorAction stop
    Copy-Item ..\source\res .\platforms\android -Recurse -ErrorAction stop
}

function build(){
    Write-Host -ForegroundColor Green "*** build ***"

    create

    Write-Host -ForegroundColor Green "  cordova build android"
    & cordova build android

    Set-Location ..
    Write-Host -ForegroundColor Green "*** build done ***"
}

function release(){
    Write-Host -ForegroundColor Green "Have yo all remembered ta update ya version numbers? (Yes), (No)"
    $kill = Read-Host '(Y)es, (N)o'
    if($kill -eq "y" -or $kill -eq "yes")
    {
        Write-Host "OK lets build a release version :-)"
    }
    else
    {
        Write-Host -ForegroundColor Green "just use the command  -  setVersion.bat 202 2.0.2"                    
        exit 1
    }


    Write-Host -ForegroundColor Green "*** release ***"

    create

    Write-Host -ForegroundColor Green "  cordova build android --release"
    & cordova build android --release

    sign

    Copy-Item .\platforms\android\bin\myapp-release-signed-aligned.apk ..\appstore\APKs\myapp-release-signed-aligned.apk -ErrorAction stop

    Set-Location ..\
    Write-Host -ForegroundColor Green "*** release done - appstore\APKs\myapp-release-signed-aligned.apk saved***"    

}

function sign(){
    Write-Host -ForegroundColor Green "*** sign ***"
#    keytool -genkey -v -keystore uas-test-key.keystore -alias uas-test-key-alias -keyalg RSA -keysize 2048 -validity 10000
#    keytool -exportcert -alias uas-test-key-alias -keystore uas-test-key.keystore -list -v

    jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore ..\appstore\android-keystore\myapp -keypass myappKeyPassword -storepass myappStorePassword -signedjar .\platforms\android\bin\myapp-release-signed.apk .\platforms\android\bin\myapp-release-unsigned.apk myapp
#    jarsigner -verify -verbose -certs .\platforms\android\bin\myapp-release-unsigned.apk

    Write-Host -ForegroundColor Green "*** zipalign ***"
    zipalign -f -v 4  .\platforms\android\bin\myapp-release-signed.apk  .\platforms\android\bin\myapp-release-signed-aligned.apk
#    zipalign -c -v 4 .\platforms\android\bin\myapp-release-signed-aligned.apk
}

function quickCopy(){	
    Write-Host -ForegroundColor Green "*** quickCopy ***"
    Remove-Item .\app-cordova-android\www -Recurse -Force -ErrorAction stop
    Copy-Item .\source\www .\app-cordova-android -Recurse -ErrorAction Stop
    Remove-Item .\app-cordova-android\www\.idea -Recurse -Force -ErrorAction ignore
    Remove-Item .\app-cordova-android\www\spec -Recurse -Force -ErrorAction stop
    Remove-Item .\app-cordova-android\www\spec.html -Recurse -Force -ErrorAction stop
    
    Set-Location .\app-cordova-android
    Write-Host -ForegroundColor Green "*** cordova build android ***"
    & cordova build android
    Write-Host -ForegroundColor Green "*** cordova build android --release ***"
    & cordova build android --release
    sign
    Copy-Item .\platforms\android\bin\myapp-release-signed-aligned.apk ..\appstore\APKs\myapp-release-signed-aligned.apk -ErrorAction stop

    Set-Location ..\
}

function installDebug(){
    Set-Location .\app-cordova-android
    & cordova run android -d
    Set-Location ..
}

function installRelease(){    
    & adb uninstall com.myapp.app
    & adb install .\appstore\APKs\myapp-release-signed-aligned.apk
}

function emulate(){
    Set-Location .\app-cordova-android
    & cordova emulate android -d
    Set-Location ..
}