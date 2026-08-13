@echo off
REM ============================================================================
REM create-project.bat
REM ------------------
REM Equivalent d'un "composer create-project" base sur ce depot Git, pour un
REM plugin WordPress (Windows).
REM
REM Ce script :
REM   1. Clone le squelette WordPress Plugin dans un nouveau dossier
REM   2. Supprime l'historique Git du squelette (depart propre)
REM   3. Remplace PLUGIN_NAME dans docker-compose.yml par le slug du plugin
REM      (deduit du repertoire de destination)
REM   4. Demarre les conteneurs Docker (build inclus)
REM
REM Usage :
REM   create-project.bat [repertoire-destination] [url-du-depot-git]
REM
REM Le repertoire de destination peut etre passe en argument ou saisi de maniere
REM interactive (par defaut : le repertoire courant "."). Il sert egalement a
REM determiner le slug du plugin (wp-content/plugins/<slug>).
REM
REM Exemple :
REM   create-project.bat                 REM demande le repertoire (defaut : .)
REM   create-project.bat mon-plugin
REM   create-project.bat mon-plugin https://github.com/GBonnaire/skeleton-wordpress-plugin.git
REM ============================================================================

setlocal enableextensions enabledelayedexpansion

set "DEFAULT_REPO=https://github.com/GBonnaire/skeleton-wordpress-plugin.git"

set "DEST=%~1"
set "REPO_URL=%~2"
if "%REPO_URL%"=="" set "REPO_URL=%DEFAULT_REPO%"

REM Demande interactive du repertoire de destination si non fourni en argument
if "%DEST%"=="" (
  set /p "DEST=Repertoire de destination [.] : "
)
if "%DEST%"=="" set "DEST=."

REM Validation du repertoire de destination
if "%DEST%"=="." (
  REM Clonage dans le repertoire courant : il doit etre vide
  for /f %%A in ('dir /b /a 2^>nul') do (
    echo Erreur : le repertoire courant n'est pas vide, impossible d'y cloner le projet.
    exit /b 1
  )
) else (
  if exist "%DEST%" (
    echo Erreur : le dossier "%DEST%" existe deja.
    exit /b 1
  )
)

REM --- Detection de la commande Docker Compose -------------------------------
set "DC="
docker compose version >nul 2>&1
if %errorlevel%==0 (
  set "DC=docker compose"
) else (
  where docker-compose >nul 2>&1
  if %errorlevel%==0 (
    set "DC=docker-compose"
  )
)
if "%DC%"=="" (
  echo Erreur : Docker Compose est introuvable. Installez Docker Desktop.
  exit /b 1
)

REM --- 1. Clonage ------------------------------------------------------------
echo ==^> Clonage de %REPO_URL% dans "%DEST%" ...
git clone "%REPO_URL%" "%DEST%"
if %errorlevel% neq 0 exit /b 1

cd "%DEST%"

REM --- 2. Reinitialisation de l'historique Git -------------------------------
echo ==^> Suppression de l'historique Git du squelette ...
rmdir /s /q .git
git init -q
echo     Nouveau depot Git initialise.

REM --- 2Bis. Suppression des fichiers du skeleton ----------------------------
del README.md

REM --- 3. Determination du slug du plugin & mise a jour de docker-compose.yml
if "%DEST%"=="." (
  for %%I in (.) do set "RAW_NAME=%%~nxI"
) else (
  for %%I in ("%DEST%") do set "RAW_NAME=%%~nxI"
)

for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "('%RAW_NAME%').ToLower() -replace '[^a-z0-9]+','-' -replace '^-+|-+$',''"`) do set "PLUGIN_SLUG=%%S"
if "%PLUGIN_SLUG%"=="" set "PLUGIN_SLUG=my-plugin"

echo ==^> Remplacement de PLUGIN_NAME par "%PLUGIN_SLUG%" dans docker-compose.yml ...
powershell -NoProfile -Command "(Get-Content docker-compose.yml) -replace 'PLUGIN_NAME', '%PLUGIN_SLUG%' | Set-Content docker-compose.yml"
if %errorlevel% neq 0 exit /b 1

REM --- 4. Demarrage de Docker ------------------------------------------------
echo ==^> Construction et demarrage des conteneurs Docker ...
%DC% up -d --build
if %errorlevel% neq 0 exit /b 1

REM Attendre que le conteneur claudeai reponde
echo ==^> Attente de la disponibilite du conteneur claudeai ...
set "CLAUDEAI_READY="
for /l %%i in (1,1,30) do (
  if not defined CLAUDEAI_READY (
    %DC% exec -T claudeai php -v >nul 2>&1
    if !errorlevel!==0 (
      set "CLAUDEAI_READY=1"
    ) else (
      timeout /t 2 /nobreak >nul
    )
  )
)
if not defined CLAUDEAI_READY (
  echo Erreur : le conteneur claudeai n'est pas pret apres 60s.
  exit /b 1
)

echo.
echo [OK] Projet initialise avec succes dans "%DEST%" (plugin : %PLUGIN_SLUG%).
echo    - WordPress   : http://localhost
echo    - PhpMyAdmin  : http://localhost:8080
echo    - MailDev     : http://localhost:8081
echo.
echo    Terminez l'installation de WordPress sur http://localhost, activez
echo    le plugin "%PLUGIN_SLUG%" depuis Extensions, puis lancez le skill
echo    Claude Code /init-skeleton depuis le conteneur claudeai :
echo      %DC% exec claudeai bash

endlocal
