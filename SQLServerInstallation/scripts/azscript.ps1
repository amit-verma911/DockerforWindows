#Install AZ CLI
#Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet' -ErrorAction Stop;

Az login --service-principal -u 47be0433-a943-4d33-aec0-a8e29fc16bd7 -p E8@D_Y9c5es11j?-KGPU4!04j5?x8_HD -t 05d75c05-fa1a-42e7-9cf1-eb416c396f2d -ErrorAction Stop;

Az storage blob download --container-name sqlserverinstallationblob --name sqlserverinstalltionalfiles.zip --account-name 001tcssandbox --account-key TaC1ss4rXqNY2CatuwuUGXYQWjYkdhHnwYvaCOx3jGlVwJe2I/6nGiuBfPC/8As97mSPfKIVONVQh09UpIiQVA== --file ~/sqlserverinstalltionalfiles.zip -ErrorAction Stop;


