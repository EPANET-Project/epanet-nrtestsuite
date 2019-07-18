::
::  run_nrtest.cmd - Runs numerical regression test
::
::  Date Created: 1/8/2018
::  Date Updated: 7/18/2019
::
::  Author: Michael E. Tryby
::          US EPA - ORD/NRMRL
::
::  Dependencies:
::    python -m pip install -r requirements.txt
::
::  Environment Variables:
::    TEST_HOME
::    BUILD_HOME
::    PLATFORM
::
::  Arguments:
::    1 - (SUT_VERSION)
::    2 - (SUT_BUILD_ID)
::

@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_HOME=%~dp0"

:: Check existence
if not defined REF_BUILD_ID (echo "ERROR: REF_BUILD_ID must be defined" & exit /B 1)

if [%1]==[] (set SUT_VERSION=
) else ( set "SUT_VERSION=%~1" )

if [%2]==[] ( set "SUT_BUILD_ID=local"
) else ( set "SUT_BUILD_ID=%~2" )


:: check if app config file exists
if not exist "apps\epanet-%SUT_BUILD_ID%.json" do (
  :: determine SUT executable path
  for /D /R "%BUILD_HOME%" %%a in (*) do (
    if /i "%%~nxa"=="bin" (
      set "BIN_HOME=%%a"
      goto break_loop_2
    )
  )
  :break_loop_2
  set "SUT_PATH=%BIN_HOME%\Release"

  :: TODO: determine SUT_VERSION here by calling runepanet.exe

  :: call app config script
  mkdir apps
  call %SCRIPT_HOME%\app-config.cmd %SUT_PATH% %PLATFORM% %SUT_BUILD_ID% %SUT_VERSION%^
     > apps\epanet-%SUT_BUILD_ID%.json
)


:: build test list
set TESTS=
for /F "tokens=*" %%T in ('dir /b tests') do ( set "TESTS=!TESTS! tests\%%T" )


:: determine location of python Scripts folder
for /F "tokens=*" %%G in ('where python') do (
  set PYTHON_DIR=%%~dpG
  goto break_loop_1
)
:break_loop_1
set "NRTEST_SCRIPT_PATH=%PYTHON_DIR%Scripts"


:: build nrtest execute command
set NRTEST_EXECUTE_CMD=python %NRTEST_SCRIPT_PATH%\nrtest execute
set TEST_APP_PATH=apps\epanet-%SUT_BUILD_ID%.json
set TEST_OUTPUT_PATH=benchmark\epanet-%SUT_BUILD_ID%

:: build nrtest compare command
set NRTEST_COMPARE_CMD=python %NRTEST_SCRIPT_PATH%\nrtest compare
set REF_OUTPUT_PATH=benchmark\epanet-ref
set RTOL_VALUE=0.01
set ATOL_VALUE=0.0

:: change current directory to test suite
cd %TEST_HOME%

:: if present clean test benchmark results
if exist %TEST_OUTPUT_PATH% (
  rmdir /s /q %TEST_OUTPUT_PATH%
)

:: perform nrtest execute
echo INFO: Creating SUT %SUT_BUILD_ID% artifacts
set NRTEST_COMMAND=%NRTEST_EXECUTE_CMD% %TEST_APP_PATH% %TESTS% -o %TEST_OUTPUT_PATH%
:: if there is an error exit the script with error value 1
%NRTEST_COMMAND% || exit /B 1

echo.

:: perform nrtest compare
echo INFO: Comparing SUT artifacts to REF %REF_BUILD_ID%
set NRTEST_COMMAND=%NRTEST_COMPARE_CMD% %TEST_OUTPUT_PATH% %REF_OUTPUT_PATH% --rtol %RTOL_VALUE% --atol %ATOL_VALUE% -o benchmark\receipt.json
%NRTEST_COMMAND%
