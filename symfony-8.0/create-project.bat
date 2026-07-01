@echo off
REM ============================================================================
REM create-project.bat
REM ------------------
REM Equivalent d'un "composer create-project" base sur ce depot Git (Windows).
REM
REM Ce script :
REM   1. Clone le squelette Symfony 8.0 dans un nouveau dossier
REM   2. Supprime l'historique Git du squelette (depart propre)
REM   3. Demarre les conteneurs Docker (build inclus)
REM   4. Lance, dans le conteneur PHP : composer install, yarn install, yarn dev
REM
REM Usage :
REM   scripts\create-project.bat [repertoire-destination] [url-du-depot-git]
REM
REM Le repertoire de destination peut etre passe en argument ou saisi de maniere
REM interactive (par defaut : le repertoire courant ".").
REM
REM Exemple :
REM   scripts\create-project.bat                 REM demande le repertoire (defaut : .)
REM   scripts\create-project.bat mon-app
REM   scripts\create-project.bat mon-app https://github.com/GBonnaire/skeleton-symfony-8.0.git
REM ============================================================================

setlocal enableextensions enabledelayedexpansion

set "DEFAULT_REPO=https://github.com/GBonnaire/skeleton-symfony-8.0.git"

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

REM --- 3. Demarrage de Docker ------------------------------------------------
echo ==^> Construction et demarrage des conteneurs Docker ...
%DC% up -d --build
if %errorlevel% neq 0 exit /b 1

REM Attendre que le conteneur PHP reponde
echo ==^> Attente de la disponibilite du conteneur PHP ...
set "PHP_READY="
for /l %%i in (1,1,30) do (
  if not defined PHP_READY (
    %DC% exec -T php php -v >nul 2>&1
    if !errorlevel!==0 (
      set "PHP_READY=1"
    ) else (
      timeout /t 2 /nobreak >nul
    )
  )
)
if not defined PHP_READY (
  echo Erreur : le conteneur PHP n'est pas pret apres 60s.
  exit /b 1
)

REM --- 4. Installation des dependances ---------------------------------------
echo ==^> composer install ...
%DC% exec -T php composer install
if %errorlevel% neq 0 exit /b 1

echo ==^> yarn install ...
%DC% exec -T php yarn install
if %errorlevel% neq 0 exit /b 1

echo ==^> yarn dev ...
%DC% exec -T php yarn dev
if %errorlevel% neq 0 exit /b 1

echo.
echo [OK] Projet initialise avec succes dans "%DEST%".
echo    - Application : http://localhost
echo    - PhpMyAdmin  : http://localhost:8080
echo    - MailDev     : http://localhost:8081

endlocal
