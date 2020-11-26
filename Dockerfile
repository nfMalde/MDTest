#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

#Depending on the operating system of the host machines(s) that will build or run the containers, the image specified in the FROM statement may need to be changed.
#For more information, please see https://aka.ms/containercompat
FROM mcr.microsoft.com/powershell:latest as installer
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';$ProgressPreference='continue';  [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls';"]
RUN Invoke-WebRequest -OutFile nodejs.zip -UseBasicParsing "https://nodejs.org/dist/v14.15.1/node-v14.15.1-win-x64.zip"; Expand-Archive nodejs.zip -DestinationPath C:\; Rename-Item node-v14.15.1-win-x64 nodejs
RUN Invoke-WebRequest -outfile portableGit.7z.exe https://github.com/git-for-windows/git/releases/download/v2.29.2.windows.2/PortableGit-2.29.2.2-64-bit.7z.exe
RUN Invoke-WebRequest -UserAgent 'DockerCI' -outfile 7zsetup.exe http://www.7-zip.org/a/7z1514-x64.exe
RUN start-process .\7zsetup.exe -ArgumentList '/S /D=c:\\7zip' -Wait
RUN start-process "c:\\7zip\\7z.exe"  -ArgumentList 'x portableGit.7z.exe -oc:\git' -Wait
 
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
RUN SETX Path "C:\\nodejs;c:\git\cmd;c:\git\bin;c:\git\usr\bin;c:\gcc\bin;%Path%"
WORKDIR /nodejs
COPY --from=installer /nodejs .
WORKDIR /git
COPY --from=installer "C:\\git" . 

WORKDIR /src
COPY ["WebApplication1/WebApplication1.csproj", "WebApplication1/"]
RUN dotnet restore "WebApplication1/WebApplication1.csproj"
WORKDIR /src/WebApplication1/ClientApp 
COPY ["WebApplication1/ClientApp/package.json", "."]
COPY ["WebApplication1/ClientApp/package-lock.json", "."] 
RUN npm i
COPY . .
WORKDIR "/src/WebApplication1"
RUN dotnet build "WebApplication1.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "WebApplication1.csproj" -c Release -o /app/publish

FROM base AS final
RUN SETX Path "C:\\nodejs;%Path%"
WORKDIR /nodejs
COPY --from=installer /nodejs .
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "WebApplication1.dll"]