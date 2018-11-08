@echo off

rem Usage: 1) make sure PATH points to qmake for 32 or 64 bit Qt directory for Microsoft Visual Studio 2015. This is
rem           typically accomplished by calling this script from Qt 5.8 shell for 'msvc2015' or 'msvc2015_64'
rem        2) build_msi_and_zip.bat 
rem
rem Requirements: 1) Path set to point to:
rem                  vcvarsall.bat           Microsoft Visual Studio X/vc/bin, where X=12.0 (MSVC2012) and 14.0 (MSVC2015) work,
rem                                          with MSVC2015 used to build supporting libraries and official releases
rem                  candle.exe/light.exe    Wix Toolset
rem                  zip.exe                 Gnuwin32
rem                  curl.exe                cURL
rem                  7z.exe                  7-Zip
rem                  qmake                   Qt 5. Typical minimal setup is provided by setup_32bit.bat
rem               2) This does NOT need the fftw3 or log4cpp libraries to be installed first, since they are
rem                  downloaded and set up automatically by this script. The DLLs supplied should work for msvc 2015

rem next line sets QTDIR to output of 'qmake -query QT_INSTALL_PREFIX'
for /f "delims=" %%a in ('qmake -query QT_INSTALL_PREFIX') do @set QTDIR=%%a

if not x%QTDIR:msvc2015_64=%==x%QTDIR% (
  rem QTDIR includes msvc2015_64 (for 64 bits)
  set ARCH=x64
  set BITS=64
  set WXSFILE=engauge_64.wxs
  set WXSOBJFILE=engauge_64.wixobj
  echo Building for Microsoft Visual Studio 2015 with 64 bits
  set /p rtn=Press Enter to continue...
) else (
  if not x%QTDIR:msvc2015=%==x%QTDIR% (
    rem QTDIR includes msvc2015 (for 32 bits)
    set ARCH=x86
    set BITS=32
    set WXSFILE=engauge.wxs
    set WXSOBJFILE=engauge.wixobj
    echo Building for Microsoft Visual Studio 2015 with 32 bits
    set /p rtn=Press any key to continue...
  ) else (
    echo Unknown build setup encountered. MSVC 2015 with 32 or 64 bits expected according to 'qmake -query'. Quitting
    set /p rtn=Press any key to continue...
    exit /b
  )
)
echo Continuing...

call vcvarsall.bat %ARCH%

set QTDIRS=bearer iconengines imageformats platforms printsupport sqldrivers
set QTLIBS=Qt5CLucene Qt5Core Qt5Gui Qt5Help Qt5Network Qt5PrintSupport Qt5Sql Qt5Widgets Qt5Xml

set SCRIPTDIR=%cd%
rem Directory containing engauge.pro
set APPVEYOR_BUILD_FOLDER=%SCRIPTDIR%\..\..
if not exist "%APPVEYOR_BUILD_FOLDER%" mkdir "%APPVEYOR_BUILD_FOLDER%"
cd "%APPVEYOR_BUILD_FOLDER%"

rem Next line is where pdf can be added for pdf support
set ENGAUGE_CONFIG=pdf
set POPPLER_INCLUDE=%APPVEYOR_BUILD_FOLDER%\dev\windows\poppler-%BITS%bit-libs\include
set POPPLER_LIB=%APPVEYOR_BUILD_FOLDER%\dev\windows\poppler-%BITS%bit-libs\lib

set QTLIBEXT='.lib'

rem Double-double quotes are needed in next line if the directory has a space
set RESULTDIR=%SCRIPTDIR%\Engauge Digitizer

rem Next step removes stale files like engauge.log from the release
if exist "%RESULTDIR%" del /Q /F "%RESULTDIR%" 2>nul
if not exist "%RESULTDIR%" mkdir "%RESULTDIR%"

set FFTW_HOME=%APPVEYOR_BUILD_FOLDER%\dev\windows\unzip_fftw
set LOG4CPP_HOME=%APPVEYOR_BUILD_FOLDER%\dev\windows\unzip_log4cpp
set SYSTEM32_HOME=%APPVEYOR_BUILD_FOLDER%\dev\windows\unzip_system32
if not exist %FFTW_HOME% mkdir %FFTW_HOME%
if not exist %LOG4CPP_HOME% mkdir %LOG4CPP_HOME%
if not exist %SYSTEM32_HOME% mkdir %SYSTEM32_HOME%

cd %FFTW_HOME%
if "%ARCH%" == "x86" (
  7z x ../appveyor/fftw-3.3.5-dll32.zip -aoa
) else (
  7z x ../appveyor/fftw-3.3.5-dll64.zip -aoa
)

if not exist include mkdir include
if not exist lib mkdir lib
move fftw3.h include
move *dll lib
move *def lib
move *.lib lib

cd lib
lib /def:libfftw3-3.def /out:libfftw3-3.lib
lib /def:libfftw3f-3.def /out:libfftw3f-3.lib
lib /def:libfftw3l-3.def /out:libfftw3l-3.lib

cd %LOG4CPP_HOME%
if exist include rmdir include /s /q
if exist lib rmdir lib /s /q
7z x ../appveyor/log4cpp_null_build.zip -aoa
if "%ARCH%" == "x86" (
  xcopy/e lib32\* .
) else (
  xcopy/e lib64\* .
)

cd %SYSTEM32_HOME%
if "%ARCH%" == "x86" (
  7z x ../appveyor/system32-32.zip -aoa
  move system32\concrt140.dll    concrt140.dll
  move system32\msvcp140.dll     msvcp140.dll
  move system32\vccorlib140.dll  vccorlib140.dll
  move system32\vcruntime140.dll vcruntime140.dll
) else (
  7z x ../appveyor/system32-64.zip -aoa
  move system32\concrt140.dll    concrt140.dll
  move system32\msvcp140.dll     msvcp140.dll
  move system32\vccorlib140.dll  vccorlib140.dll
  move system32\vcruntime140.dll vcruntime140.dll
)

cd "%SCRIPTDIR%"
echo "*** engauge.wxs ***"
git diff --word-diff --unified=0 engauge.wxs 2>nul | findStr "["
findStr "Id='" engauge.wxs | findStr /v Component | findStr /v Directory | findStr /v Feature | findStr /v File | findStr /v Folder | findStr /v Media | findStr /v Package | findStr /v Property 
findStr "Version=" engauge.wxs | findStr /v InstallerVersion

echo "*** engauge_64.wxs ***"
git diff --word-diff --unified=0 engauge_64.wxs 2>nul | findStr "["
findStr "Id='" engauge_64.wxs | findStr /v Component | findStr /v Directory | findStr /v Feature | findStr /v File | findStr /v Folder | findStr /v Media | findStr /v Package | findStr /v Property 
findStr "Version=" engauge_64.wxs | findStr /v InstallerVersion

echo "*** Version.cpp ***"
findStr "char *VERSION_NUMBER" ..\..\src\util\Version.cpp

echo "*** info_valid.plist ***"
findStr "<string>1" ..\osx\info_valid.plist

echo *************************************************************************
echo * Check the version numbers and Ids above. If they are not correct, enter
echo * Control-C to exit. Otherwise, enter the version number below...
echo *
echo * CAUTION - Do not use the mouse wheel at this point or else the
echo * entered number will be blank
echo *************************************************************************
set /p VERNUM="Version number seen above>"
echo Version number will be %VERNUM%

cd "%APPVEYOR_BUILD_FOLDER%"

echo *************************************
echo APPVEYOR_BUILD_FOLDER: %APPVEYOR_BUILD_FOLDER%
echo current directory:
cd
echo ENGAUGE_CONFIG: %ENGAUGE_CONFIG%
echo FFTW_HOME: %FFTW_HOME%
echo LOG4CPP_HOME: %LOG4CPP_HOME%
echo POPPLER_INCLUDE: %POPPLER_INCLUDE%
echo POPPLER_LIB: %POPPLER_LIB%
echo QTDIRS: %QTDIRS%
echo QTLIBS: %QTLIBS%
echo RESULTDIR: %RESULTDIR%
echo SYSTEM32_HOME: %SYSTEM32_HOME%
echo *************************************
set /p VERNUM="Press Enter to continue..."
echo Continuing...

lrelease engauge.pro
if exist Makefile del /S Makefile
qmake engauge.pro "CONFIG+=%ENGAUGE_CONFIG%" 

if not exist Makefile (
   echo qmake command has failed. Quitting
   exit /b 1
)

if not exist bin mkdir bin

rem move Makefile Makefile.orig
rem ps: gc Makefile.orig | %{ $_ -replace '551.lib', %QTLIBEXT% } > Makefile
nmake clean

rem Make sure the log4cpp library is built with debug info to prevent 'mismatch deteced for _ITERATOR_DEBUG_LEVEL'
nmake release

if not exist bin/engauge.exe (
  echo Executable could not be built. Stopping
  exit /b 1
)

cd "%APPVEYOR_BUILD_FOLDER%"
if not exist "%RESULTDIR%"\documentation mkdir "%RESULTDIR%"\documentation
for %%I in (%QTDIRS%) do (
  if not exist "%RESULTDIR%\%%I" mkdir "%RESULTDIR%\%%I"
)
for %%I in (%QTDIRS%) do echo copy %QTDIR%\plugins\%%I\*.dll
for %%I in (%QTDIRS%) do copy "%QTDIR%\plugins\%%I\*.dll" "%RESULTDIR%\%%I"
for %%I in (%QTLIBS%) do echo copy %QTDIR%\bin\%%I.dll
for %%I in (%QTLIBS%) do copy "%QTDIR%\bin\%%I.dll" "%RESULTDIR%"
if exist *d.dll del /S *d.dll
copy bin\engauge.exe "%RESULTDIR%"

copy LICENSE "%RESULTDIR%"
cd "%APPVEYOR_BUILD_FOLDER%"\help
qcollectiongenerator engauge.qhcp -o engauge.qhc
move engauge.qch "%RESULTDIR%"\documentation
move engauge.qhc "%RESULTDIR%"\documentation
cd ..

copy "%POPPLER_LIB%\freetype.dll"     "%RESULTDIR%"
copy "%POPPLER_LIB%\openjp2.dll"      "%RESULTDIR%"
copy "%POPPLER_LIB%\poppler.dll"      "%RESULTDIR%"
copy "%POPPLER_LIB%\poppler-qt5.dll"  "%RESULTDIR%"
copy "%POPPLER_LIB%\zlib.dll"         "%RESULTDIR%"
copy "%FFTW_HOME%\lib\libfftw3-3.dll" "%RESULTDIR%"
copy "%LOG4CPP_HOME%\lib\log4cpp.dll" "%RESULTDIR%"
copy "%SYSTEM32_HOME%\*"              "%RESULTDIR%"

copy "%APPVEYOR_BUILD_FOLDER%"\translations "%RESULTDIR%"

7z a "%RESULTDIR%.7z" "%RESULTDIR%"

echo ***creating msi
cd "%SCRIPTDIR%"
candle %WXSFILE%
candle WixUI_InstallDir_NoLicense.wxs
light.exe -ext WixUIExtension -ext WixUtilExtension %WXSOBJFILE% WixUI_InstallDir_NoLicense.wixobj -o "digit-exe-windows-%BITS%-bit-installer-%VERNUM%.msi"

echo *** creating zip
rem "Engauge Digitizer" in next line is needed since zip crashes on %RESULTDIR% due to the space
zip -r "digit-exe-windows-%BITS%-bit-without-installer-file-%VERNUM%.zip" "Engauge Digitizer"
