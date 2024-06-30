/**********************************************************************************************
* Copyright (C) 2024 Acoustic, L.P. All rights reserved.
*
* NOTICE: This file contains material that is confidential and proprietary to
* Acoustic, L.P. and/or other developers. No license is granted under any intellectual or
* industrial property rights of Acoustic, L.P. except as may be provided in an agreement with
* Acoustic, L.P. Any unauthorized copying or distribution of content from this file is
* prohibited.
**********************************************************************************************/

pipeline {
  agent {
    label 'osx'
  }

  environment {
    SONAR_HOME = "/Users/Shared/Developer/sonar-scanner-4.6.0.2311-macosx/bin"
    SONAR_BUILD_WRAPPER = "/Users/Shared/Developer/build-wrapper-macosx-x86/build-wrapper-macosx-x86"
    PATH="${PATH}:${GEM_HOME}/bin"
  }

  stages {
    stage('Setup Beta') {
      when { anyOf { branch 'feature/*'; branch 'develop' } }
      steps {
        echo "Set up settings..${env.GIT_BRANCH}"
        script{
          createBuild("${env.GIT_BRANCH}")
          if (genBuild) {
            checkoutRepo()
            cleanProject()
          }
        }
      }
    }

    stage('Setup Release') {
      when { branch 'main' }
      steps {
        echo "Set up settings..main"
        script{
          createBuild("main")
          if (genBuild) {
            checkoutReleaseRepo()
            cleanProject()
          }
        }
      }
    }

    stage('Lint') {
      when { anyOf { branch 'feature/*'; branch 'develop'; branch 'main' } }
      steps {
        echo 'Run lint'
        script{
          if (genBuild) {
            getLintSummary()
          }
        }
      }
    }

    stage('Unit tests') {
      when { anyOf { branch 'feature/*'; branch 'develop'; branch 'main' } }
      steps {
        echo 'Run unit tests'
        script{
          if (genBuild) {
            runUnitTests()
          }
        }
      }
    }

    stage('Android integration tests') {
      when { anyOf { branch 'feature/*'; branch 'develop'; branch 'main' } }
      steps {
        echo 'Run Android integration tests'
        script{
          if (genBuild) {
            runIntegrationTests(true)
            junit testResults: "${buildDir}/test-results/xml/TEST-android_integration_test.xml", skipPublishingChecks: true
          }
        }
      }
    }

    stage('iOS integration tests') {
      when { anyOf { branch 'feature/*'; branch 'develop'; branch 'main' } }
      steps {
        echo 'Run iOS integration tests'
        script{
          if (genBuild) {
            runIntegrationTests(false)
            junit testResults: "${buildDir}/test-results/xml/TEST-ios_integration_test.xml", skipPublishingChecks: true
          }
        }
      }
    }

    stage('Gallery App Android Build') {
      when { anyOf { branch 'feature/*'; branch 'develop'; branch 'main' } }
      steps {
        echo 'Verify Gallery App Android Build'
        script{
          if (genBuild) {
            runCMD("cd ${buildDir}/example/gallery && flutter build apk --debug --no-tree-shake-icons") 
          }
        }
      }
    }

    stage('Verify Gallery App iOS Build') {
      when { anyOf { branch 'feature/*'; branch 'develop'; branch 'main' } }
      steps {
        echo 'Verify Gallery App iOS Build'
        script{
          if (genBuild) {
            runCMD("cd ${buildDir}/example/gallery && flutter build ios-framework --debug --no-tree-shake-icons") 
          }
        }
      }
    }

    stage('Publish Beta') {
        when { branch 'develop' }
        steps {
            script {
                echo "Current branch: ${env.GIT_BRANCH}"
                echo "genBuild value: ${genBuild}"
            }
            script{
                if (genBuild) {
                    echo 'Publish Beta....'
                    publishHelper(true)
                }
            }
        }
    }


    stage('Publish Release') {
      when { branch 'main'}
      steps {
        script{
          echo "genBuild value: ${genBuild}"

          if (genBuild) {
            echo 'Publish Release....'
            publishHelper(false)
          }
        }
      }
    }

    stage('Slack Report - NonRelease') {
      when { anyOf { branch 'feature/*'; branch 'develop'; } }
      steps {
        echo 'Slack Report....'
        script{
          if (genBuild) {
            getSlackReport(false)
          }
        }
      }
    }

    stage('Slack Report - Release') {
      when { anyOf { branch 'main' } }
      steps {
        echo 'Slack Report....'
        script{
          if (genBuild) {
            getSlackReport(true)
          }
        }
      }
    }
  }

  post {
    // Clean after build
    success {
      cleanWs cleanWhenNotBuilt: false, cleanWhenFailure: false, cleanWhenUnstable: false, deleteDirs: true, disableDeferredWipeout: true, patterns: [[pattern: "**/Reports/**", type: 'EXCLUDE']]
    }
    aborted {
      cleanWs cleanWhenNotBuilt: false, cleanWhenFailure: false, cleanWhenUnstable: false, deleteDirs: true, disableDeferredWipeout: true, patterns: [[pattern: "**/Reports/**", type: 'EXCLUDE']]
    }
  }
}

import groovy.transform.Field
import groovy.json.JsonOutput
import java.util.Optional
import hudson.tasks.test.AbstractTestResultAction
import hudson.model.Actionable
import hudson.tasks.junit.CaseResult
import hudson.model.Action
import hudson.model.AbstractBuild
import hudson.model.HealthReport
import hudson.model.HealthReportingAction
import hudson.model.Result
import hudson.model.Run
import hudson.plugins.cobertura.*
import hudson.plugins.cobertura.targets.CoverageMetric
import hudson.plugins.cobertura.targets.CoverageTarget
import hudson.plugins.cobertura.targets.CoverageResult
import hudson.util.DescribableList
import hudson.util.Graph
import groovy.json.JsonSlurper
import groovy.json.JsonOutput
import groovy.util.slurpersupport.*
import java.text.SimpleDateFormat
import groovy.io.FileType

// Global variables
@Field def name              = "Connect-Flutter"

// Slack reporting
@Field def gitAuthor         = ""
@Field def lastCommitMessage = ""
@Field def testSummary       = "No tests found"
@Field def coverageSummary   = "No test coverage found"
@Field def lintSummary       = "Lint report is null"
@Field def total             = 0
@Field def failed            = 0
@Field def skipped           = 0

// Version stuff
@Field def currentVersion = ""
@Field def srcBranch

// Commit stuff
@Field def commitDesciption = ""

// Directory paths
@Field def tempTestDir = "${name}Build"
@Field def testAppDir  = "example/gallery"
@Field def buildDir    = "${tempTestDir}/Connect-Flutter-beta"
@Field def testDir     = "${buildDir}/test"
@Field def releaseDir  = "${tempTestDir}/Connect-Flutter"
@Field def buildIosDir = "${testAppDir}/ios/derived"
@Field def homeDir     = "/Users/easdk"

// Report directory paths
@Field def reportsDir = "${buildDir}/test-results"
@Field def junitDir   = "${reportsDir}"

// Files
@Field def pubspecFile   = "${buildDir}/pubspec.yaml"
@Field def changeLogFile = "${buildDir}/CHANGELOG.md"

// Build information
@Field def genBuild  = true

// Test platform
@Field def platform        = "iOS Simulator,name=iPhone 14 Plus,OS=16.0"
@Field def platformName    = platform.replaceAll(/\s|,|=|\./, "_")
@Field def platformLatest  = "17.0.1"
@Field def androidEmulator = "A_32_Tealeaf"
@Field def emulatorId      = ""
@Field def defaultIphone   = "iPhone 14 Pro"

def createBuild(sourceBranch) {
  // Setup correct branch
  srcBranch  = sourceBranch

  def findText = ""
  if (sourceBranch == "main") {
    findText = "${name} Release"
  } else {
    findText = "Beta ${name} build"
  }
  
  def resullt = hasTextBasedOnLastCommit(findText)
  if (resullt == 0) {
    genBuild = false
    currentBuild.result = 'ABORTED'
  } else {
    genBuild = true
  }

  echo "genBuild text value: ${findText}"
  echo "To genBuild?  ${genBuild}"

  // platformLatest = runCMD("xcrun simctl list | grep -w \"\\-\\- iOS\" | tail -1 | sed -r 's/[--]+//g' | sed -r 's/[iOS ]+//g' ")
  platformLatest = runCMD("xcrun simctl list | grep -w \"\\-\\- iOS\" | tail -1 | sed -r 's/[--]+//g' | sed -r 's/[iOS ]+//g' ")
  platform = "iOS Simulator,name=iPhone 15 Plus,OS=${platformLatest}"
}

// "Get library build version number"
def getLibVersion() {
  def pubspec = readYaml file: pubspecFile
  currentVersion = pubspec.version
  echo "Current version ${currentVersion}"
}

// "Update library build version number"
def updateLibVersion(isBeta) {
  echo "Get version from:${pubspecFile}"
  // Get file to update and save
  def pubspec = readYaml file: "${pubspecFile}"
  currentVersion = pubspec.version
  echo "Current version ${currentVersion}"
  currentVersion = currentVersion.replace("-beta", "")

  def libVersionArray = currentVersion.split("\\.")
  def major = libVersionArray[0] 
  int minor = libVersionArray[1].toInteger()
  int patch = libVersionArray[2].toInteger()

  if (isBeta) {
    patch = patch + 1
  } else {
    minor = minor + 1
    patch = 0
  }
  currentVersion = "${major}.${minor}.${patch}"

  if (isBeta) {
    currentVersion = currentVersion + "-beta"
  }

  echo "Updated to library version ${currentVersion}"

  runCMD("rm -f ${pubspecFile}")
  pubspec.version = currentVersion
  pubspec["build-name"] = currentVersion
  pubspec["build-number"] = currentVersion
  writeYaml file: pubspecFile, data: pubspec

  // Updated file
  def updatedFileContent = readFile "${pubspecFile}"
  echo "Updated file"
  echo "${updatedFileContent}"
}

def cleanProject() {
  echo 'Clean Project'

  echo "Delete pubspec.lock"
  runCMD("rm -f pubspec.lock")
  runCMD("cd ${buildDir}/test && rm -f pubspec.lock")
  runCMD("cd ${buildDir}/example && rm -f pubspec.lock")
  runCMD("cd ${buildDir}/package/connect_cli && rm -f pubspec.lock")

  echo "clean and pub get"
  runCMD("cd ${buildDir} && flutter clean && flutter pub get")
  runCMD("cd ${buildDir}/test && flutter clean && flutter pub get")
  runCMD("cd ${buildDir}/example && flutter clean && flutter pub get")
  runCMD("cd ${buildDir}/package/connect_cli && flutter clean && flutter pub get")
}

def runUnitTests() {
  fileName      = "connect_flutter_plugin_test"
  testFile      = "${testDir}/${fileName}.dart"
  failCount     = 0

  // Check if test-results directory exist and if it does delete it and creates new directories 
  cleanMkDir("${buildDir}/test-results/")
  cleanMkDir("${buildDir}/test-results/xml")
  cleanMkDir("${buildDir}/test-results/jsonl")

  runCMD("cd ${testDir} && flutter clean && flutter pub get")
  runCMD("cd ${testDir} && dart pub global activate junitreport")

  // Runs the unit test and creates a json file
  echo "Running unit test"
  runCMD("flutter test ${testFile} --machine --verbose > ${buildDir}/test-results/jsonl/TEST-${fileName}.jsonl")

  // Creates a xml file from jsonl
  echo "Creating xml file"
  runCMD("dart pub global run junitreport:tojunit --input ${buildDir}/test-results/jsonl/TEST-${fileName}.jsonl --output ${buildDir}/test-results/xml/TEST-${fileName}-ori")
  runCMD("cat ${buildDir}/test-results/xml/TEST-${fileName}-ori | sed -e 's/&#x1B;//g' > ${buildDir}/test-results/xml/TEST-${fileName}.xml")

  def testResultSummary = junit "${buildDir}/test-results/xml/TEST-${fileName}.xml"
  if (testResultSummary != null) {
    failCount = testResultSummary.getFailCount()
  }

  if (failCount >= 0) {
    echo "No issues"
  } else {
    echo "Found ${failCount} failures in the test results. Will not create release package."
    currentBuild.result = 'ABORTED'
    return
  }
}

def runIntegrationTests(isAndroid) {
  echo "Check if test-results directory exist and if it does delete it and creates new directories"
  cleanMkDir("${testDir}/scripts/test-results")
  cleanMkDir("${testDir}/scripts/test-results/xml")
  cleanMkDir("${testDir}/scripts/test-results/jsonl")

  if (fileExists("${buildDir}/test-results/")) {
    echo "Directory ${buildDir}/test-results/ already exists"
  } else {
    cleanMkDir("${buildDir}/test-results/")
  }
  
  runCMD("cd ${buildDir} && flutter clean && flutter pub get")
  runCMD("cd ${buildDir}/example/gallery && flutter clean && flutter pub get")

  if (isAndroid) {
    def error
    parallel (
      launchEmulator: {
        startAndroidEmulator()
      },
      runAndroidTests: {
        timeout(time: 20, unit: 'SECONDS') {
          sh "adb wait-for-device"
        }
        try {
          deviceId = runCMD("flutter devices | grep -o -E 'emulator-\\d+'")
          
          sleep 30
          echo "Device ${deviceId} started."
          echo "Running integration tests for platform ${deviceId}..."
          
          fileName = "android_integration_test"
          packageName = "com.example.connect_flutter_plugin_example"
          runCMD("adb -s ${deviceId} shell pm grant ${packageName} android.permission.WRITE_EXTERNAL_STORAGE")
          runCMD("adb -s ${deviceId} shell pm grant ${packageName} android.permission.READ_EXTERNAL_STORAGE")

          runTest("${buildDir}/example/gallery", "../../test-results", deviceId, fileName)
        } catch(e) {
            error = e
        } finally {
          killAndroidEmulator()
        }
      }
    )
    if (error != null) {
      throw error
    }
  } else {
    echo "Starting iOS device..."
    startIosSim()
    deviceId = runCMD("flutter devices | grep -o -e \"[0-9A-F\\-]\\{36\\}\"")

    echo "Device ${deviceId} started."
    // echo "Running integration tests for platform ${device}..."

    fileName = "ios_integration_test"
    runTest("${buildDir}/example/gallery", "../../test-results", deviceId, fileName)
    killIosSim()
  }
}

def runTest(dir, testPath, deviceId, fileName) {
  // Runs the integration test
  echo "Running integration test"
  runCMD("cd ${dir}/ios && pod repo update")
  runCMD("cd ${dir} && flutter test --machine --verbose integration_test -d ${deviceId} > ${testPath}/jsonl/TEST-${fileName}.json")

  sleep 30

  // Creates a xml file from jsonl
  echo "Creating xml file"
  runCMD("cd ${dir} && dart pub global run junitreport:tojunit --input ${testPath}/jsonl/TEST-${fileName}.json --output ${testPath}/xml/TEST-${fileName}.xml")
}

def startIosSim() {
  def list = runCMD("xcrun simctl list -j")
  def simulators = new groovy.json.JsonSlurper().parseText(list)
  
  def isBooted = false
  simulators.devices.each { deviceType, devices ->
      devices.each { device ->
          if (device.name == defaultIphone && device.state == 'Booted') {
              isBooted = true
          }
      }
  }
  
  if (isBooted) {
      echo "The $defaultIphone simulator is already booted."
  } else {
      // Boot the simulator
      runCMD("xcrun simctl boot \"${defaultIphone}\"")
  }
}

def killIosSim() {
  echo "Kill iOS Simulator"
  sh script: "sleep 10"
  runCMD("xcrun simctl shutdown \"${defaultIphone}\"")
}

def startAndroidEmulator() {
  echo "Starting android device..."
  sh "$ANDROID_HOME/emulator/emulator -avd A_32_Tealeaf -engine auto -wipe-data -no-cache -no-boot-anim -memory 3072 -no-snapshot &exit 0"
}

def killAndroidEmulator() {
  echo "Kill Android Emulator"
  runCMD("adb devices | grep emulator | cut -f1 | while read line; do adb -s \$line emu kill; done")
}

def runCMD(commnd) {
  echo "${commnd}"
  OUUUTTPT = sh (
    script: "#!/bin/zsh -l\n ${commnd}",
    returnStdout: true
  ).trim()
  echo "${OUUUTTPT}"
  return OUUUTTPT
}

def cleanMkDir(cmDir) {
  removeDir(cmDir)
  runCMD("mkdir -p ${cmDir}")
}

def removeDir(cmDir) {
  def exists = fileExists "${cmDir}"
  if (exists) {
    runCMD("rm -rf ${cmDir}")
  }
}

// "Checkout repo and also switch to beta branch"
def checkoutRepo() {
  // Setup temp directory for repos for publishing
  echo "Create test push location: ${tempTestDir}"
  cleanMkDir("${tempTestDir}")
  runCMD("cd ${tempTestDir} && git clone git@github.com:aipoweredmarketer/Connect-Flutter-beta.git -b ${srcBranch}")
  runCMD("cd ${tempTestDir} && git clone git@github.com:go-acoustic/Connect-Flutter.git -b main")
}

def checkoutReleaseRepo() {
  // Setup temp directory for repos for publishing
  echo "Create test push location: ${tempTestDir}"
  cleanMkDir("${tempTestDir}")
  runCMD("cd ${tempTestDir} && git clone git@github.com:aipoweredmarketer/Connect-Flutter-beta.git -b main")
  runCMD("cd ${tempTestDir} && git clone git@github.com:go-acoustic/Connect-Flutter.git -b main")
}

def gitPush(path, commitMsg, tagMsg, branch, commitMsg2) {
  echo "Git Push for: ${path}"
  runCMD('''cd \"''' + path + '''\" && git add . -A''')
  runCMD('''cd \"''' + path + '''\" && git commit -a -m \"''' + commitMsg + '''\" -m \"''' + commitMsg2 + '''\"''')

  // Tag repos
  echo "Tag repos"
  runCMD('''cd \"''' + path + '''\" && git tag -f \"''' + tagMsg + '''\" -m \"''' + commitMsg2 + '''\"''')

  // Pull from git
  echo "Pull from git"
  runCMD('''cd \"''' + path + '''\" && git pull --rebase origin \"''' + branch + '''\"''')

  // Push to git
  echo "Push to git"
  runCMD('''cd \"''' + path + '''\" && git push -f --tags''')
  runCMD('''cd \"''' + path + '''\" && git push -f --set-upstream origin \"''' + branch + '''\"''')
}

// "Update files for beta"
def updateDescription() {
  def commitDesciptionTitle = "Beta ${name} Change Notes:"
  commitDesciption = readFile "latestChanges"
  commitDesciption = "${commitDesciptionTitle} \n" << commitDesciption
  commitDesciption = commitDesciption.replaceAll("\"", "\'")
}

def publishHelper(isBeta) {
  commitStart = isBeta ? "Beta" : "Release"
  updateLibVersion(isBeta)
  updateDescription()
  def commitMsg = "${commitStart} ${name} build: ${currentVersion}"
  echo "push with:"
  echo commitMsg
  echo currentVersion
  echo commitDesciption

  // Update CHANGELOG.md
  changeLog = readFile changeLogFile
  changeLog = "## ${currentVersion}\n${commitDesciption}\n" << changeLog
  writeFile(file:"${changeLogFile}", text: "${changeLog}")

  echo "Clean up directory in public repo"
  runCMD("cd ${releaseDir} && git rm -f -r .")

  echo "Copy over changes from beta to public repo"
  runCMD("rsync -av --exclude='.git' ${buildDir}/. ${releaseDir}")
  runCMD("rm -f ${releaseDir}/.metadata")
  runCMD("rm -f ${releaseDir}/Jenkinsfile")
  runCMD("rm -f ${releaseDir}/latestChanges")
  runCMD("rm -f ${releaseDir}/pubspec.lock")
  runCMD("rm -rf ${releaseDir}/scripts")
  runCMD("rm -rf ${releaseDir}/test")
  runCMD("rm -rf ${releaseDir}/.vscode")
  runCMD('''cd \"''' + releaseDir + '''\" && git add . -A''')

  // push repos
  gitPush("${buildDir}", commitMsg, currentVersion, srcBranch, commitDesciption)
  gitPush("${releaseDir}", commitMsg, currentVersion, "main", commitDesciption)

  // TODO:  hint warning requires different naming convention
  echo "Running Dry Run.  Known issue with -beta at the end."
  runCMD("cd ${buildDir} && flutter pub publish --dry-run --verbose || true")

  echo "Running Pub Dev Publish"
  runCMD("cd ${buildDir} && flutter pub publish --force")
}

def populateSlackMessageGlobalVariables() {
  getLastCommitMessage()
  getGitAuthor()
  getLibVersion()
  testSummary = getTestSummary()
  if (lintSummary == "Lint report is null") {
    getLintSummary()
  }
}

def getGitAuthor() {
  def commit = sh(returnStdout: true, script: 'git rev-parse HEAD')
  gitAuthor = sh(returnStdout: true, script: "git --no-pager show -s --format='%an' ${commit}").trim()
}

def getLastCommitMessage() {
  lastCommitMessage = sh(returnStdout: true, script: 'git log -1 --pretty=%B').trim()
}

def getTestSummary() {
  def testResultSummary = junit "${junitDir}/xml/*.xml"
  def summary = "No tests found"

  if (testResultSummary != null) {
    total   = testResultSummary.getTotalCount()
    failed  = testResultSummary.getFailCount()
    skipped = testResultSummary.getSkipCount()

    summary = "Passed: " + (total - failed - skipped)
    summary = summary + (", Failed: " + failed)
    summary = summary + (", Skipped: " + skipped)
  }
  return summary
}

def getLintSummary() {
  lintSummary = "Lint report is empty"
  issuesCount = 0

  runCMD("cd ${buildDir} && flutter clean && flutter pub get")
  lintSummary = runCMD("cd ${buildDir} && flutter analyze . --no-pub --no-fatal-warnings || exit 0")
  testCount = lintSummary.findAll(/error/)
  echo "Lint result:${lintSummary}"
  issuesCount = issuesCount + testCount.size()

  if (lintSummary.contains("No issues found!")) {
    runCMD("cd ${buildDir}/example/gallery && flutter clean && flutter pub get")
    lintSummary = runCMD("cd ${buildDir}/example/gallery && flutter analyze . --no-pub --no-fatal-warnings || exit 0")
    echo "Lint result for example/gallery:\n${lintSummary}"
    testCount = lintSummary.findAll(/error/)
    issuesCount = issuesCount + testCount.size()
  }

  lintSummary = "No. of Warnings: ${issuesCount}"
}

def hasTextBasedOnLastCommit(findText) {
  def resullt
  script {
    resullt = sh (script:'''git log -1 | grep -c \"''' + findText + '''\"
          ''', returnStatus: true)
  }
  return resullt
}


def getSlackReport(isRelease) {
  populateSlackMessageGlobalVariables()

  def releaseTitle = ""
  if (isRelease) {
    releaseTitle = "********************Release********************\n"
  }

  echo "currentBuild.result:${currentBuild.result}"

  def buildColor  = "good"
  def jobName     = "${env.JOB_NAME}"
  def buildStatus = "Success"

  if (currentBuild.result != null) {
    buildStatus = currentBuild.result
    if (buildStatus == "FAILURE") {
      failed = 9999
    }
  }

  // Strip the branch name out of the job name (ex: "Job Name/branch1" -> "Job Name")
  // echo "job name::;${jobName}"
  jobName = jobName.getAt(0..(jobName.lastIndexOf('/') - 1))

  if (failed > 0) {
    buildStatus = "Failed"
    buildColor  = "danger"
    def failedTestsString = "No current tests now"

    notifySlack([
      [
        title: "${jobName}, build #${env.BUILD_NUMBER}",
        title_link: "${env.BUILD_URL}",
        color: "${buildColor}",
        author_name: "${gitAuthor}",
        text: "${releaseTitle}${buildStatus}",
        fields: [
          [
            title: "Repo",
            value: "${name}",
            short: true
          ],
          [
            title: "Branch",
            value: "${env.GIT_BRANCH}",
            short: true
          ],
          [
            title: "pub.dev build",
            value: "https://pub.dev/packages/connect_flutter_plugin/versions/${currentVersion}",
            short: false
          ],
          [
            title: "Version",
            value: "${currentVersion}",
            short: false
          ],
          [
            title: "Test Results",
            value: "${testSummary}",
            short: true
          ],
          [
            title: "Lint Results",
            value: "${lintSummary}",
            short: true
          ],
          [
            title: "Last Commit",
            value: "${lastCommitMessage}",
            short: false
          ]
        ]
      ]
      ,
      [
        title: "Failed Tests",
        color: "${buildColor}",
        text: "${failedTestsString}",
        "mrkdwn_in": ["text"],
      ]
    ], buildColor)          
  } else {
    notifySlack([
      [
        title: "${jobName}, build #${env.BUILD_NUMBER}",
        title_link: "${env.BUILD_URL}",
        color: "${buildColor}",
        author_name: "${gitAuthor}",
        text: "${releaseTitle}${buildStatus}",
        fields: [
          [
            title: "Repo",
            value: "${name}",
            short: true
          ],
          [
            title: "Branch",
            value: "${env.GIT_BRANCH}",
            short: true
          ],
          [
            title: "pub.dev build",
            value: "https://pub.dev/packages/connect_flutter_plugin/versions/${currentVersion}",
            short: false
          ],
          [
            title: "Version",
            value: "${currentVersion}",
            short: false
          ],
          [
            title: "Test Results",
            value: "${testSummary}",
            short: true
          ],
          [
            title: "Lint Results",
            value: "${lintSummary}",
            short: true
          ],
          [
            title: "Last Commit",
            value: "${lastCommitMessage}",
            short: false
          ]
        ]
      ]
    ], buildColor)
  }
}

def notifySlack(attachments, buildColor) {    
  slackSend attachments: attachments, color: buildColor, channel: '#sdk-github'
  slackSend attachments: attachments, color: buildColor, channel: '#sdk-ci-flutter-bender'
}

return this


