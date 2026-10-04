$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open((Resolve-Path 'scratch\test_doc.doc').Path)
# Find LISTE DES FIGURES
for ($i = 60; $i -le $doc.Paragraphs.Count; $i++) {
    $p = $doc.Paragraphs.Item($i)
    if ($p.Range.Text -match "LISTE\s*DES\s*FIGURES" -and $p.Range.Text -notmatch "\t") {
        Write-Output ("Target paragraph is {0}" -f $i)
        # Inspect paragraphs before it
        for ($k = $i - 1; $k -ge 1; $k--) {
            $prev = $doc.Paragraphs.Item($k)
            if ($prev.Range.Text.Trim() -eq "") {
                Write-Output ("Deleting empty paragraph {0}" -f $k)
                $prev.Range.Delete()
            } else {
                break
            }
        }
        break
    }
}
# Now find LISTE DES FIGURES again and set PageBreakBefore and SpaceBefore = 0
for ($i = 60; $i -le $doc.Paragraphs.Count; $i++) {
    $p = $doc.Paragraphs.Item($i)
    if ($p.Range.Text -match "LISTE\s*DES\s*FIGURES" -and $p.Range.Text -notmatch "\t") {
        $p.Range.ParagraphFormat.PageBreakBefore = $true
        $p.Range.ParagraphFormat.SpaceBefore = 0
        Write-Output ("Set PageBreakBefore=$true and SpaceBefore=0 on {0}" -f $i)
        break
    }
}
$doc.Save()
$doc.Close($false)
$word.Quit()
Write-Output "Test doc modified and saved successfully!"
