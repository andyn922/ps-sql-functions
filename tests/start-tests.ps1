## Init

# get functions 
. "..\param-sql-functions.ps1"

$input_cs = "Data Source=APLAB-ANDYLP1\LYNCAP;Database=LocalTestDB;Integrated Security=True"
$input_Connection = New-ParamSQLConnection -ConnectionString $input_cs

## Main

# delete
New-ParamSQLQuery -Connection $input_Connection -Table "TestTable1" -DeleteMode
#New-ParamSQLQuery -Connection $input_Connection -DeleteMode -Table "TestTable1" -Filter "value like '%delete me'"

# insert & update
$ids = @(); 1 .. 5 | foreach-object {
    $id = New-ParamSQLQuery -Connection $input_Connection -Table "TestTable1" -GetIDBack -InsertKeyValue @{
        "name" = "random bits"
        "value" = "timestamp $((get-date).ToString())"
        "bool-alpha" = $($true, $false | Get-Random)
        "bool-bravo" = $false
        "bool-charlie" = $($true, $false | Get-Random)
    }

    $ids += $id
}

1 .. 2 | foreach-object {
    $id = $ids | Get-Random
    New-ParamSQLQuery -Connection $input_Connection -Table "TestTable1" -Filter "id = '$id'" -UpdateKeyValue @{
        "bool-bravo" = $true
    }
}

# select
New-ParamSQLQuery -Connection $input_Connection -Table "TestTable1" -SelectColumns "*"
#New-ParamSQLQuery -Connection $input_Connection -Table "TestTable1" -SelectColumns "*" -Filter "id < 5"

# custom
$subdir = ".\custom-test-files"
#New-ParamSQLQuery -Connection $input_Connection -Table "TestTable1" -CustomFilePath "$subdir\no-replacements.sql"
New-ParamSQLQuery -Connection $input_Connection -Table "TestTable1" -CustomFilePath "$subdir\replacments.sql" -CustomReplacements @{
    '%_int1' = (Get-Random -Minimum 1 -Maximum 10)
    '%_int2' = (Get-Random -Minimum 1 -Maximum 10)
}