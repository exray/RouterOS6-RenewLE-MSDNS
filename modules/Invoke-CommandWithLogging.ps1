function Invoke-CommandWithLogging {
    param (
        [scriptblock]$functionToCall,
        [array]$functionArguments,
        [string]$BeforeText,
        [string]$AfterText,
        [string]$ForegroundColor = "Red"
    )

    Write-Host "[$((Get-Date).ToString("HH:mm:ss"))] " -ForegroundColor Yellow -NoNewline
    Write-Host $BeforeText -ForegroundColor DarkBlue
    
    $originalForegroundColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $ForegroundColor

    # Вызываем переданную функцию с переданными аргументами
    & $functionToCall $functionArguments

    Write-Host "[$((Get-Date).ToString("HH:mm:ss"))] " -ForegroundColor Yellow -NoNewline
    Write-Host $AfterText -ForegroundColor DarkGreen

    $Host.UI.RawUI.ForegroundColor = $originalForegroundColor
}

# Использовать так:
# Invoke-CommandWithLogging -functionToCall ${function:Start-Something} -functionArguments @("важное дело") -BeforeText "Начал делать дела" -AfterText "Закончил делать дела" -ForegroundColor Cyan
