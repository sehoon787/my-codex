@ECHO off
REM my-codex Windows cmd.exe wrapper - runs SessionStart hook then delegates to real codex.cmd
REM Required because Windows shells don't execute extensionless bash wrapper at ~/.codex/bin/codex.
SETLOCAL EnableDelayedExpansion

REM Run SessionStart hook via bash if available (Git Bash / WSL / MSYS).
REM Failures are swallowed; hook output is discarded (nothing in Codex consumes it).
WHERE bash >NUL 2>NUL
IF !ERRORLEVEL! EQU 0 (
  IF EXIST "%USERPROFILE%\.codex\hooks\session-start.sh" (
    bash "%USERPROFILE%\.codex\hooks\session-start.sh" >NUL 2>NUL
  )
)

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
