//
//  TymeHelper.swift
//  TymeHelper
//
//  Created by Michel Storms on 22/04/2026.
//
//  CLI tool that queries Tyme 3 for time logged on a task and compares it
//  against a budgeted number of hours. Auto-detects the current Xcode project
//  name from the working directory and maps it to a Tyme task via a config file.
//
//  Config:  ~/.config/tymehelper/projects.json
//  Install: Scripts/install.sh
//
//  Usage:
//    tymehelper                                  # auto-detect project from cwd
//    tymehelper MyApp                            # explicit project name
//    tymehelper set <project> <task> <hrs> <rate> # configure a project budget
//
//  Example:
//    tymehelper set MyApp "MyApp - Billable" 80 75
//    cd ~/Source/MyApp && tymehelper
//

import Foundation

// MARK: - Config

/// Budget configuration for a single project.
/// Maps an Xcode project name to a Tyme task name with hourly budget and rate.
struct ProjectBudget: Codable {
    let hours: Double    // total budgeted hours
    let rate: Double     // hourly rate in USD
    let tymeTask: String // task name in Tyme 3 (e.g. "MyApp - Billable")
}

/// Top-level config keyed by Xcode project name.
struct Config: Codable {
    var projects: [String: ProjectBudget]
}

// MARK: - Tyme Query

/// Queries Tyme 3 via AppleScript for total timed hours on a specific task.
///
/// Tyme hierarchy: Project > Task > TaskRecord. This function finds the task
/// by name across all projects, then sums `timedDuration` for all matching
/// task records from 2025 onwards.
///
/// - Parameter taskName: The exact task name in Tyme (e.g. "MyApp - Billable")
/// - Returns: Total hours logged, or nil if the task was not found
func queryTyme(taskName: String) -> Double? {
    let script = """
    tell application "Tyme"
        -- Find the task ID by iterating all projects and tasks
        set targetTaskID to ""
        repeat with p in (every project)
            repeat with t in (every task of p)
                if name of t is "\(taskName)" then
                    set targetTaskID to id of t
                end if
            end repeat
        end repeat

        if targetTaskID is "" then
            return -1
        end if

        -- Fetch all task records from 2025-01-01 to now
        set s to current date
        set month of s to January
        set day of s to 1
        set year of s to 2025
        set hours of s to 0
        set minutes of s to 0
        set seconds of s to 0

        GetTaskRecordIDs startDate s endDate (current date)
        set allRecords to fetchedTaskRecordIDs as list

        -- Sum durations for records belonging to the target task
        set totalSeconds to 0
        repeat with i from 1 to count of allRecords
            set recordID to item i of allRecords
            GetRecordWithID recordID
            if relatedTaskID of lastFetchedTaskRecord is targetTaskID and recordType of lastFetchedTaskRecord is "timed" then
                set totalSeconds to totalSeconds + (timedDuration of lastFetchedTaskRecord)
            end if
        end repeat

        return totalSeconds
    end tell
    """

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        print("Error running osascript: \(error)")
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          let seconds = Double(output) else {
        return nil
    }

    if seconds < 0 {
        return nil
    }

    return seconds / 3600.0
}

// MARK: - Project Detection

/// Auto-detects the Xcode project name from the current working directory.
///
/// Searches for a `.xcodeproj` bundle in the cwd and one level down (e.g. `macOS/`
/// subdirectory, common in multi-platform projects). Falls back to the directory name.
func detectProjectName() -> String? {
    let cwd = FileManager.default.currentDirectoryPath
    let url = URL(fileURLWithPath: cwd)

    let searchDirs = [url, url.appendingPathComponent("macOS")]

    for dir in searchDirs {
        if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for item in contents {
                if item.pathExtension == "xcodeproj" {
                    return item.deletingPathExtension().lastPathComponent
                }
            }
        }
    }

    return url.lastPathComponent
}

// MARK: - Config Management

/// Returns the path to the config file: ~/.config/tymehelper/projects.json
func configPath() -> URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".config/tymehelper/projects.json")
}

/// Loads the config from disk, returning an empty config if the file doesn't exist.
func loadConfig() -> Config {
    let path = configPath()
    guard let data = try? Data(contentsOf: path),
          let config = try? JSONDecoder().decode(Config.self, from: data) else {
        return Config(projects: [:])
    }
    return config
}

/// Saves the config to disk, creating the directory if needed.
func saveConfig(_ config: Config) {
    let path = configPath()
    let dir = path.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(config) {
        try? data.write(to: path)
    }
}

// MARK: - Formatting

/// Formats a decimal hours value as "Xh YYm" (e.g. 11.5 → "11h 30m").
func formatHours(_ hours: Double) -> String {
    let h = Int(hours)
    let m = Int((hours - Double(h)) * 60)
    return "\(h)h \(String(format: "%02d", m))m"
}

// MARK: - Helpers

/// Checks if Tyme 3 is currently running via System Events.
func isTymeRunning() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", "tell application \"System Events\" to (name of processes) contains \"Tyme\""]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try? process.run()
    process.waitUntilExit()
    let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return result == "true"
}

func printUsage() {
    print("""
    Usage:
      tymehelper                                       Auto-detect project from cwd
      tymehelper <project>                             Query a specific project
      tymehelper set <project> <task> <hours> <rate>   Configure a project budget

    Examples:
      tymehelper set MyApp "MyApp - Billable" 80 75
      cd ~/Source/MyApp && tymehelper
    """)
}

// MARK: - Main

@main
struct TymeHelperCLI {
    static func main() {
        let args = CommandLine.arguments

        // tymehelper set <project> <tymeTask> <hours> <rate>
        if args.count >= 2 && args[1] == "set" {
            guard args.count >= 6 else {
                print("Usage: tymehelper set <project> <tymeTask> <hours> <rate>")
                return
            }
            let project = args[2]
            let tymeTask = args[3]
            guard let hours = Double(args[4]), let rate = Double(args[5]) else {
                print("Error: hours and rate must be numbers.")
                return
            }
            var config = loadConfig()
            config.projects[project] = ProjectBudget(hours: hours, rate: rate, tymeTask: tymeTask)
            saveConfig(config)
            print("Set \(project) → \"\(tymeTask)\": \(Int(hours)) hours @ $\(Int(rate))/hr ($\(Int(hours * rate)) total)")
            return
        }

        // tymehelper help
        if args.count >= 2 && (args[1] == "help" || args[1] == "--help" || args[1] == "-h") {
            printUsage()
            return
        }

        // tymehelper [project]
        let project: String
        if args.count >= 2 {
            project = args[1]
        } else if let detected = detectProjectName() {
            project = detected
        } else {
            printUsage()
            return
        }

        guard isTymeRunning() else {
            print("Tyme is not running.")
            return
        }

        // Look up the Tyme task name from config, fall back to project name
        let config = loadConfig()
        let budget = config.projects[project]
        let tymeTask = budget?.tymeTask ?? project

        guard let hours = queryTyme(taskName: tymeTask) else {
            print("Task \"\(tymeTask)\" not found in Tyme.")
            if budget == nil {
                print("No config for \"\(project)\". Run: tymehelper set \(project) \"<tyme task>\" <hours> <rate>")
            }
            return
        }

        // Display summary
        print("")
        print("  \(project)")
        print("  ──────────────────────────────")
        print("  Logged:     \(formatHours(hours))")

        if let budget {
            let totalBudget = budget.hours * budget.rate
            let spent = hours * budget.rate
            let remaining = budget.hours - hours
            let pct = (hours / budget.hours) * 100

            print("  Budget:     \(formatHours(budget.hours)) (\(Int(pct))% used)")
            print("  Remaining:  \(formatHours(max(remaining, 0)))")
            print("")
            print("  Rate:       $\(Int(budget.rate))/hr")
            print("  Spent:      $\(String(format: "%.0f", spent)) / $\(String(format: "%.0f", totalBudget))")
            print("  Left:       $\(String(format: "%.0f", max(totalBudget - spent, 0)))")
        }

        print("")
    }
}
