@ECHO off
REM my-codex Windows cmd.exe wrapper - runs SessionStart hook then delegates to real codex.cmd
REM Required because Windows shells don't execute extensionless bash wrapper at ~/.codex/bin/codex.
SETLOCAL EnableDelayedExpansion

REM Run SessionStart hook via bash if available (Git Bash / WSL / MSYS).
REM Failures are swallowed; hook output is discarded (nothing in Codex consumes it).
SET "HOOK_OK=no"
IF EXIST "%USERPROFILE%\.codex\hooks\session-start.sh" SET "HOOK_OK=yes"
WHERE bash >NUL 2>NUL
IF !ERRORLEVEL! EQU 0 (
  IF EXIST "%USERPROFILE%\.codex\hooks\session-start.sh" (
    bash "%USERPROFILE%\.codex\hooks\session-start.sh" >NUL 2>NUL
  )
)

REM Diagnostic log
FOR /F "tokens=*" %%T IN ('powershell -NoProfile -Command "Get-Date -UFormat '%%Y-%%m-%%dT%%H:%%M:%%SZ'" 2^>NUL') DO SET "TS=%%T"
IF NOT DEFINED TS SET "TS=unknown"
>> "%USERPROFILE%\.codex\last-invocation.log" ECHO !TS!	wrapper=codex.cmd	cwd=!CD!	hook_installed=!HOOK_OK!

REM Find the real codex.cmd - skip our own wrapper directory to avoid recursion.
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

CALL "!REAL_CMD!" %*
EXIT /B !ERRORLEVEL!
