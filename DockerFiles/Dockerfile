# Dockerfile to install IIS and .net framework with windows server core -2019. 
###Base Image###
#indicates that the windowsservercore image will be used as the base image.
#FROM mcr.microsoft.com/windows/servercore:ltsc2019
#updated to use maersk approved windows server core image

FROM mcr.microsoft.com/windows/servercore:ltsc2019

#Metadate indicating image maintainer
LABEL maintainer="Amit Verma"

# Team ownership
LABEL brand="Abc"
LABEL product.name="Some Product"
LABEL product.team="Some Team"

###Add .net Framework###
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

#added argument for passing the version
#ARG Version

#Instal .net framework with version
#RUN Install-WindowsFeature NET-Framework-$env:Version-ASPNET ; \
   #Install-WindowsFeature Web-Asp-Net$env:Version 

RUN Install-WindowsFeature NET-Framework-45-ASPNET ; \
    Install-WindowsFeature Web-Asp-Net45


###Add IIS###
RUN powershell -command \
    Add-WindowsFeature Web-Server; 

#adding tls to website
RUN powershell.exe -Command " \
    Import-Module IISAdministration; \
    $cert = New-SelfSignedCertificate -DnsName demo.google.com -CertStoreLocation cert:\LocalMachine\My; \
    $certHash = $cert.GetCertHash(); \
    $sm = Get-IISServerManager; \
    $sm.Sites[\"Default Web Site\"].Bindings.Add(\"*:443:\", $certHash, \"My\", \"0\"); \
    $sm.CommitChanges();"

#specify a command to run on coantainer setup
CMD [ "cmd" ]
