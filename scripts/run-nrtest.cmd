::
::  run_nrtest.cmd - Runs numerical regression test
::
::  Date Created: 1/8/2018
::  Date Updated: 7/16/2018
::
::  Author: Michael E. Tryby
::          US EPA - ORD/NRMRL
::
::  Arguments:
::    1 - (SUT version identifier)
::    2 - (SUT build identifier)
::

@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_HOME=%~dp0"

:: Check existence
IF NOT DEFINED REF_BUILD_ID (echo "ERROR: REF_BUILD_ID must be defined" & exit /B 1)

IF [%1]==[] (set SUT_VERSION=
) ELSE ( set "SUT_VERSION=%~1" )

IF [%2]==[] ( set "SUT_BUILD_ID=local"
) ELSE ( set "SUT_BUILD_ID=%~2" )


:: determine location of python Scripts folder
FOR /F "tokens=*" %%G IN ('where python') DO (
  set PYTHON_DIR=%%~dpG
  GOTO break_loop_1
)
:break_loop_1
set "NRTEST_SCRIPT_PATH=%PYTHON_DIR%Scripts"


IF NOT EXIST "apps\epanet-%SUT_BUILD_ID%.json" DO (
  :: determine SUT executable path
  FOR /D /R "%BUILD_HOME%" %%a IN (*) DO (
    IF /i "%%~nxa"=="bin" (
      set "BIN_HOME=%%a"
      GOTO break_loop_2
    )
  )
  :break_loop_2
  set "SUT_PATH=%BIN_HOME%\Release"

  :: generate json configuration file for software under test
  mkdir apps
  CALL %SCRIPT_HOME%\app-config.cmd %SUT_PATH% %PLATFORM% %SUT_BUILD_ID% %SUT_VERSION%^
     > apps\epanet-%SUT_BUILD_ID%.json
)


:: build test list
set TESTS=
FOR /F "tokens=*" %%T IN ('dir /b tests') DO ( set "TESTS=!TESTS! tests\%%T" )


set NRTEST_EXECUTE_CMD=python %NRTEST_SCRIPT_PATH%\nrtest execute
set TEST_APP_PATH=apps\epanet-%SUT_BUILD_ID%.json
set TEST_OUTPUT_PATH=benchmark\epanet-%SUT_BUILD_ID%

set NRTEST_COMPARE_CMD=python %NRTEST_SCRIPT_PATH%\nrtest compare
set REF_OUTPUT_PATH=benchmark\epanet-%REF_BUILD_ID%
set RTOL_VALUE=0.01
set ATOL_VALUE=0.0

:: change current directory to test suite
cd %TEST_HOME%

:: if present clean test benchmark results
if exist %TEST_OUTPUT_PATH% (
  rmdir /s /q %TEST_OUTPUT_PATH%
)

echo INFO: Creating SUT %SUT_BUILD_ID% artifacts
set NRTEST_COMMAND=%NRTEST_EXECUTE_CMD% %TEST_APP_PATH% %TESTS% -o %TEST_OUTPUT_PATH%
:: if there is an error exit the script with error value 1
%NRTEST_COMMAND% || exit /B 1

echo.

echo INFO: Comparing SUT artifacts to REF %REF_BUILD_ID%
set NRTEST_COMMAND=%NRTEST_COMPARE_CMD% %TEST_OUTPUT_PATH% %REF_OUTPUT_PATH% --rtol %RTOL_VALUE% --atol %ATOL_VALUE% -o benchmark\receipt.json
%NRTEST_COMMAND%
