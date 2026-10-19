@echo off
rem Gradle wrapper entry for Windows (the POSIX script is `gradlew`).
rem Uses Android Studio's bundled JBR when java.exe isn't on the PATH.
setlocal
set "APP_HOME=%~dp0"
set "JAVA_EXE=java"
if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" set "JAVA_EXE=C:\Program Files\Android\Android Studio\jbr\bin\java.exe"
"%JAVA_EXE%" -cp "%APP_HOME%gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*
