content = File.read("FlowTimer/FlowTimer/Managers/TimerManager.swift")

content.gsub!(/Task \{\n\s+await self\.initialize\(\)\n\s+\}/, "Task { [weak self] in\n            await self?.initialize()\n        }")

# Replace saveState Task
content.gsub!(/Task \{\n\s+let engineSnapshot = await engine\.snapshot\(\)/, "Task { [weak self] in\n            guard let self else { return }\n            let engineSnapshot = await engine.snapshot()")

# Replace settingsDidChange Task
content.gsub!(/Task \{\n\s+let duration: Int/, "Task { [weak self] in\n                guard let self else { return }\n                let duration: Int")

# Replace advanceToNextPhase completion Task
content.gsub!(/Task \{\n\s+switch phase \{/, "Task { [weak self] in\n            guard let self else { return }\n            switch phase {")

# Replace takeBreak Task
content.gsub!(/Task \{\n\s+await engine\.pause\(\)\n\s+if let startDate = currentPhaseStartDate/, "Task { [weak self] in\n            guard let self else { return }\n            await engine.pause()\n            \n            if let startDate = currentPhaseStartDate")

# Replace skipCurrentPhase Task
content.gsub!(/Task \{\n\s+await engine\.pause\(\)\n\s+currentPhaseStartDate = nil/, "Task { [weak self] in\n            guard let self else { return }\n            await engine.pause()\n            currentPhaseStartDate = nil")

# Replace start Task
content.gsub!(/Task \{\n\s+await engine\.start\(\)\n\s+\}/, "Task { [weak self] in\n            await self?.engine.start()\n        }")

# Replace pause Task
content.gsub!(/Task \{\n\s+await engine\.pause\(\)\n\s+\}/, "Task { [weak self] in\n            await self?.engine.pause()\n        }")

# Replace resume Task
content.gsub!(/Task \{\n\s+await engine\.resume\(\)\n\s+\}/, "Task { [weak self] in\n            await self?.engine.resume()\n        }")

# Replace reset Task
content.gsub!(/Task \{\n\s+currentSession = 1/, "Task { [weak self] in\n            guard let self else { return }\n            currentSession = 1")

File.write("FlowTimer/FlowTimer/Managers/TimerManager.swift", content)
puts "Updated TimerManager.swift"
