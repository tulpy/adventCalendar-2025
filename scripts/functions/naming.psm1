#region Functions

# Function to generate a unique Azure string based on an input string and a seed value.
function Get-AzureUniqueString {
  param(
    [Parameter(Mandatory = $true)]
    [string]$InputString,

    [uint]$seed = 0u
  )

  # Convert input string to byte array
  [uint[]] $dataArray = [System.Text.Encoding]::UTF8.GetBytes($InputString)
  [int] $num = $dataArray.Length
  [uint] $num2 = $seed
  [uint] $num3 = $seed
  $index = 0

  # Process data in chunks of 8 bytes
  for ($index = 0; $index + 7 -lt $num; $index += 8) {
    [uint] $num4 = [uint]($dataArray[$index] -bor ($dataArray[$index + 1] -shl 8) -bor ($dataArray[$index + 2] -shl 16) -bor ($dataArray[$index + 3] -shl 24))
    [uint] $num5 = [uint] ($dataArray[$index + 4] -bor ($dataArray[$index + 5] -shl 8) -bor ($dataArray[$index + 6] -shl 16) -bor ($dataArray[$index + 7] -shl 24))

    $num4 = Get-UncheckedUInt32Multiply $num4 597399067
    $num4 = scramble -value $num4 -count 15
    $num4 = Get-UncheckedUInt32Multiply $num4 2869860233u
    $num2 = $num2 -bxor $num4
    $num2 = scramble -value $num2 -count 19
    $num2 = Get-UncheckedUInt32Addition $num2 $num3
    $num2 = Get-UncheckedUInt32Addition (Get-UncheckedUInt32Multiply $num2 5) 1444728091

    $num5 = Get-UncheckedUInt32Multiply $num5 2869860233u
    $num5 = scramble -value $num5 -count 17
    $num5 = Get-UncheckedUInt32Multiply $num5 597399067
    $num3 = $num3 -bxor $num5
    $num3 = scramble -value $num3 -count 13
    $num3 = Get-UncheckedUInt32Addition $num3 $num2
    $num3 = Get-UncheckedUInt32Addition (Get-UncheckedUInt32Multiply $num3 5) 197830471
  }

  # Process remaining bytes
  $num6 = [int]($num - $index)
  if ($num6 -gt 0) {
    $elseVal = switch ($num6) {
      2 { [uint]($dataArray[$index] -bor ($dataArray[$index + 1] -shl 8)) }
      3 { [uint]($dataArray[$index] -bor ($dataArray[$index + 1] -shl 8) -bor ($dataArray[$index + 2] -shl 16)) }
      default { $dataArray[$index] }
    }

    $num7 = [uint](($num6 -ge 4) ? ([uint]($dataArray[$index] -bor ($dataArray[$index + 1] -shl 8) -bor ($dataArray[$index + 2] -shl 16) -bor ($dataArray[$index + 3] -shl 24))) : $elseVal)
    $num7 = Get-UncheckedUInt32Multiply $num7 597399067
    $num7 = scramble -value $num7 -count 15
    $num7 = Get-UncheckedUInt32Multiply $num7 2869860233u
    $num2 = $num2 -bxor $num7

    if ($num6 -gt 4) {
      $value = switch ($num6) {
        6 { Get-UncheckedUInt32Multiply ($dataArray[$index + 4] -bor ($dataArray[$index + 5] -shl 8)) -1425107063 }
        7 { Get-UncheckedUInt32Multiply ($dataArray[$index + 4] -bor ($dataArray[$index + 5] -shl 8) -bor ($dataArray[$index + 6] -shl 16)) -1425107063 }
        default { Get-UncheckedUInt32Multiply ($dataArray[$index + 4]) -1425107063 }
      }
      $value = scramble -value $value -count 17
      $value = Get-UncheckedUInt32Multiply $value 597399067
      $num3 = $num3 -bxor $value
    }
  }

  # Final scrambling and conversion
  $num2 = $num2 -bxor [uint]$num
  $num3 = $num3 -bxor [uint]$num
  $num2 = Get-UncheckedUInt32Addition $num2 $num3
  $num3 = Get-UncheckedUInt32Addition $num3 $num2
  $num2 = $num2 -bxor $num2 -shr 16
  $num2 = Get-UncheckedUInt32Multiply $num2 2246822507u
  $num2 = $num2 -bxor $num2 -shr 13
  $num2 = Get-UncheckedUInt32Multiply $num2 3266489909u
  $num2 = $num2 -bxor $num2 -shr 16
  $num3 = $num3 -bxor $num3 -shr 16
  $num3 = Get-UncheckedUInt32Multiply $num3 2246822507u
  $num3 = $num3 -bxor $num3 -shr 13
  $num3 = Get-UncheckedUInt32Multiply $num3 3266489909u
  $num3 = $num3 -bxor $num3 -shr 16
  $num2 = Get-UncheckedUInt32Addition $num2 $num3
  $num3 = Get-UncheckedUInt32Addition $num3 $num2

  $final = ([ulong]$num3 -shl 32) -bor $num2
  $uniqueString = Get-Base32Encode $final
  return $uniqueString
}

# Base32 encoding characters
$encodeLetters = "abcdefghijklmnopqrstuvwxyz234567"

# Function to perform bitwise scrambling
function scramble {
  param (
    [uint] $value,
    [int] $count
  )
  return ($value -shl $count) -bor ($value -shr (32 - $count))
}

# Function to encode a ulong value to a Base32 string
function Get-Base32Encode {
  param (
    [ulong] $longVal
  )
  $strOutput = ""
  for ($i = 0; $i -lt 13; $i++) {
    $charIdx = [int]($longVal -shr 59)
    $charAddition = $encodeLetters[$charIdx]
    $strOutput = $strOutput + $charAddition
    $longVal = $longVal -shl 5;
  }
  return $strOutput
}

# Function to decode a Base32 string to a BigInteger
function Get-Base32Decode {
  param (
    [string] $encodedString
  )
  $bigInteger = [Numerics.BigInteger]::Zero
  for ($i = 0; $i -lt $encodedString.Length; $i++) {
    $char = $encodedString[$i]
    $ltrIdx = $encodeLetters.IndexOf($char)
    $bigInteger = ($bigInteger -shl 5) -bor $ltrIdx
  }
  return $bigInteger / 2
}

# Function to perform unchecked 32-bit unsigned integer multiplication
function Get-UncheckedUInt32Multiply {
  param (
    [long] $nbrOne,
    [long] $nbrTwo
  )

  $nbrOnePos = $nbrOne -lt 0 ? [uint]::MaxValue - (-$nbrOne) + 1 : $nbrOne
  $nbrTwoPos = $nbrTwo -lt 0 ? [uint]::MaxValue - (-$nbrTwo) + 1 : $nbrTwo

  $uintMaxVal = [uint]::MaxValue
  $longMultiplyResult = ([ulong]$nbrOnePos * [ulong]$nbrTwoPos)
  $remainder = $longMultiplyResult % $uintMaxVal
  $totalDivisions = ($longMultiplyResult - $remainder) / $uintMaxVal
  $result = $remainder - $totalDivisions

  if ($result -lt 0) {
    return ($uintMaxVal - (-$result)) + 1
  }
  return $result
}

# Function to perform unchecked 32-bit unsigned integer addition
function Get-UncheckedUInt32Addition {
  param (
    [uint] $nbrOne,
    [uint] $nbrTwo
  )

  $nbrOnePos = $nbrOne -lt 0 ? [uint]::MaxValue - (-$nbrOne) + 1 : $nbrOne
  $nbrTwoPos = $nbrTwo -lt 0 ? [uint]::MaxValue - (-$nbrTwo) + 1 : $nbrTwo

  $uintMaxVal = [uint]::MaxValue
  $longAdditionResult = ($nbrOnePos + $nbrTwoPos)
  $remainder = $longAdditionResult % $uintMaxVal
  $totalLoops = ($longAdditionResult - $remainder) / $uintMaxVal
  $result = [System.Math]::Abs($remainder - $totalLoops)

  return $result
}

#endregion

Export-ModuleMember -Function * -Verbose:$false
