function Get-ErrorPresence {
    # Если в переменной Error есть элементы (aka есть какие-то ошибки), то вернётся $true, иначе - $false
    # $Error.Count -ne 0
    if ($Error.Count -ne 0) {
        return $true
    } else {
        $Error.Clear()
        return $false
    }
}