@ECHO off
REM my-codex Windows cmd.exe wrapper - runs SessionStart hook via Git Bash then delegates to real codex.cmd.
REM CRITICAL: invoke Git Bash explicitly - System32\bash.exe is WSL bash and fails on Windows paths.
SETLOCAL EnableDelayedExpansion

SET "GIT_BASH="
IF EXIST "%ProgramFiles%\Git\bin\bash.exe" SET "GIT_BASH=%ProgramFiles%\Git\bin\bash.exe"
IF NOT DEFINED GIT_BASH IF EXIST "%ProgramFiles%\Git\usr\bin\bash.exe" SET "GIT_BASH=%ProgramFiles%\Git\usr\bin\bash.exe"
IF NOT DEFINED GIT_BASH IF EXIST "%ProgramFiles(x86)%\Git\bin\bash.exe" SET "GIT_BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"

SET "HOOK_OK=no"
IF EXIST "%USERPROFILE%\.codex\hooks\session-start.sh" SET "HOOK_OK=yes"

IF DEFINED GIT_BASH (
  IF "!HOOK_OK!"=="yes" (
    "!GIT_BASH!" "%USERPROFILE%\.codex\hooks\session-start.sh" 1>NUL 2>NUL
  )
)

FOR /F "tokens=*" %%T IN ('powershell -NoProfile -Command "Get-Date -UFormat '%%Y-%%m-%%dT%%H:%%M:%%SZ'" 2^>NUL') DO SET "TS=%%T"
IF NOT DEFINED TS SET "TS=unknown"
>> "%USERPROFILE%\.codex\last-invocation.log" ECHO !TS!	wrapper=codex.cmd	cwd=!CD!	hook_installed=!HOOK_OK!	git_bash=!GIT_BASH!

SET "SELF_DIR=%~dp0"
SET "REAL_CMD="
FOR /F "delims=" %%i IN ('WHERE codex.cmd 2^>NUL') DO (
  IF /I NOT "%%~dpi"=="!SELF_DIR!" (
    IF NOT DEFINED REAL_CMD SET "REAL_CMD=%%i"
  )
)

IF NOT DEFINED REAL_CMD (
  ECHO my-codex: real codex.cmd not found in PATH. >&2
  EXIT /B 127
)

SET "CODEX_WRAPPER_INVOKED=1"
CALL "!REAL_CMD!" %*
EXIT /B !ERRORLEVEL!
