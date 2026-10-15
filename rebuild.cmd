pskill dlGrep
set SD=D:\SourceCode\Git\dlGrep\
dotnet build dnGREP.OpenXmlEngine\dnGREP.OpenXmlEngine.csproj -c Debug -p:Platform=x64 -p:SolutionDir=%SD%
dotnet build dnGREP.PdfEngine\dnGREP.PdfEngine.csproj -c Debug -p:Platform=x64 -p:SolutionDir=%SD%
dotnet build dnGREP.WordEngine\dnGREP.WordEngine.csproj -c Debug -p:Platform=x64 -p:SolutionDir=%SD%
dotnet build dnGREP.WPF\dnGREP.WPF.csproj -c Debug -p:Platform=x64 -p:SolutionDir=%SD%
