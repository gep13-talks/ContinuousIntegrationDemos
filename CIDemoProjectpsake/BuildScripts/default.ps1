# The creation of this build script (and associated files) was only possible using the 
# work that was done on the BoxStarter Project on GitHub:
# http://boxstarter.codeplex.com/
# Big thanks to Matt Wrock (@mwrockx} for creating this project, thanks!

$psake.use_exit_on_error = $true

Import-Module "..\SharedBinaries\psake\teamcity.psm1"

properties {
	$config = 'Debug';
	$projectName = "CIDemo";
}

$private = "This is a private task not meant for external use!";

function get-buildArtifactsDirectory {
	return "." | Resolve-Path | Join-Path -ChildPath "../BuildArtifacts";
}

function get-testArtifactsDirectory {
	return "." | Resolve-Path | Join-Path -ChildPath "../TestArtifacts";
}

function get-sourceDirectory {
	return "." | Resolve-Path | Join-Path -ChildPath "../";
}

function create-PackageDirectory( [Parameter(ValueFromPipeline=$true)]$packageDirectory ) {
    process {
        Write-Verbose "checking for package path $packageDirectory...";
        if( !(Test-Path $packageDirectory ) ) {
    		Write-Verbose "creating package directory at $packageDirectory...";
    		mkdir $packageDirectory | Out-Null;
    	}
    }    
}

function remove-PackageDirectory( [Parameter(ValueFromPipeline=$true)]$packageDirectory ) {
	process {
		Write-Verbose "Checking directory at $packageDirectory...";
        if(Test-Path $packageDirectory) {
    		Write-Verbose "Removing directory at $packageDirectory...";
    		Remove-Item $packageDirectory -recurse -force;
    	}
	}
}

Task -Name Default -Depends RebuildSolution

# private tasks

Task -Name __VerifyConfiguration -Description $private -Action {
	Assert ( @('Debug', 'Release') -contains $config ) "Unknown configuration, $config; expecting 'Debug' or 'Release'";
}

Task -Name __CreateBuildArtifactsDirectory -Description $private -Action {
	get-buildArtifactsDirectory | create-packageDirectory;
}

Task -Name __RemoveBuildArtifactsDirectory -Description $private -Action {
	get-buildArtifactsDirectory | remove-packageDirectory;
}

Task -Name __CreateTestArtifactsDirectory -Description $private -Action {
	get-testArtifactsDirectory | create-packageDirectory;
}

Task -Name __RemoveTestArtifactsDirectory -Description $private -Action {
	get-testArtifactsDirectory | remove-packageDirectory;
}

# primary targets

Task -Name RebuildSolution -Depends CleanSolution, __CreateBuildArtifactsDirectory, __CreateTestArtifactsDirectory, BuildSolution, TestSolution -Description "Rebuilds the main solution for the package"

# build tasks

Task -Name BuildSolution -Depends __VerifyConfiguration -Description "Builds the main solution for the package" -Action {
	$sourceDirectory = get-sourceDirectory;
	exec { 
		msbuild "$sourceDirectory\CIDemoProject.sln" /t:Build /p:Configuration=$config
	}
}

# clean tasks

Task -Name CleanSolution -Depends __RemoveBuildArtifactsDirectory, __RemoveTestArtifactsDirectory, __VerifyConfiguration -Description "Deletes all build artifacts" -Action {
	$sourceDirectory = get-sourceDirectory;
	exec {
		msbuild "$sourceDirectory\CIDemoProject.sln" /t:Clean /p:Configuration=$config
	}
}

# test tasks

Task -Name TestSolution -Description "Uses NUnit to execute Unit Tests for Solution" -Action {
	$sourceDirectory = get-sourceDirectory;
	$testOutputDirectory = get-testArtifactsDirectory;
	$testAssembly = Join-Path -Path $sourceDirectory -ChildPath "BuildArtifacts\CIDemoProject.Tests.dll" | Resolve-Path
	
	exec {
		& "$sourceDirectory\SharedBinaries\NUnit\nunit-console-x86.exe" $testAssembly /nologo /nodots /labels
	}
	
	Move-Item "TestResult.xml" $testOutputDirectory
	
	TeamCity-ImportNUnitReport "$testOutputDirectory\TestResult.xml"
}