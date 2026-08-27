package io.github.developmentnetwork

import java.io.File
import java.net.InetSocketAddress
import java.net.ServerSocket
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.tasks.TaskAction
import org.gradle.jvm.tasks.Jar

/**
 * runNetwork — the "run-paper of the network": spawns the whole dev network
 * (Velocity proxy + lobby + this plugin's managed dev backend) with an
 * automatically-registered free port, then blocks like runServer does.
 *
 * Wiring (consumer build.gradle.kts):
 *   plugins { id("io.github.development-network") }
 *   (with the plugin published/added via includeBuild)
 *
 * Properties:
 *   -PnetworkBackend=<name>   backend name (default: project.name)
 *   -PnetworkBase=<dir>       network runtime dir (default: run/network)
 *   -PdevNetworkBin=<dir>     harness bin dir (default:
 *                             $DEV_NETWORK_BIN, or ROOT/development-network/bin)
 *   -PnetworkProxyPort=<n>    proxy port (default: 25565; 0 = auto-pick free)
 *   -PnetworkJarTask=<name>   Jar task to deploy (default: "jar")
 */
class DevNetworkPlugin : Plugin<Project> {
    override fun apply(project: Project) {
        project.tasks.register("runNetwork", RunNetworkTask::class.java) { task ->
            task.group = "network"
            task.description = "Spawn the dev network (proxy + lobby + this plugin) with auto port registration"
            task.dependsOn(project.findProperty("networkJarTask") as String? ?: "jar")
        }
    }
}

abstract class RunNetworkTask : DefaultTask() {

    @TaskAction
    fun runNetwork() {
        val project = project
        fun prop(name: String): String? = project.findProperty(name) as String?

        fun findFreePort(start: Int): Int {
            var p = start
            while (p < 65535) {
                val s = ServerSocket()
                try {
                    s.reuseAddress = true
                    s.bind(InetSocketAddress("127.0.0.1", p))
                    return p
                } catch (_: java.io.IOException) {
                    p++
                } finally {
                    s.close()
                }
            }
            throw GradleException("no free port found from $start")
        }

        val base = prop("networkBase") ?: "run/network"
        val name = prop("networkBackend") ?: project.name
        check(name.matches(Regex("[A-Za-z0-9_-]+"))) {
            "networkBackend '$name' invalid (use [A-Za-z0-9_-]+)"
        }

        // Harness bin dir: -PdevNetworkBin > $DEV_NETWORK_BIN > ROOT/development-network/bin.
        val harnessBin = prop("devNetworkBin")
            ?.let { project.file(it).absolutePath }
            ?: System.getenv("DEV_NETWORK_BIN")
            ?: project.rootProject.projectDir.resolve("development-network/bin").takeIf { it.isDirectory }?.absolutePath
        check(harnessBin != null && project.file("$harnessBin/dev-network.sh").isFile) {
            "development-network harness bin not found — set -PdevNetworkBin or \$DEV_NETWORK_BIN"
        }

        val baseDir = project.layout.projectDirectory.dir(base).asFile
        val pluginsDir = baseDir.resolve("runtime/auto/$name/plugins")
        pluginsDir.mkdirs()

        // Stale CalVer jars accumulate; deploy only the fresh one.
        pluginsDir.listFiles { f -> f.extension == "jar" }?.forEach { it.delete() }

        // Deploy the actual Jar task output (respects archiveBaseName/Version,
        // shadowJar, multi-module). 'jar' is the default dependsOn.
        val jarTaskName = prop("networkJarTask") ?: "jar"
        val jarTask = project.tasks.named(jarTaskName).get()
        val jarFile = (jarTask as? Jar)?.archiveFile?.get()?.asFile
            ?: error("task '$jarTaskName' is not a Jar task — set -PnetworkJarTask to a Jar task")
        check(jarFile.isFile) { "missing $jarFile — run $jarTaskName first" }
        jarFile.copyTo(pluginsDir.resolve(jarFile.name), overwrite = true)

        // Auto port registration: proxy (free or 0=auto) + backend free port.
        val proxyPortProp = prop("networkProxyPort")?.toIntOrNull() ?: 25565
        val proxyPort = if (proxyPortProp == 0) findFreePort(25565) else proxyPortProp
        val backendPort = findFreePort(30067)
        println("== runNetwork: backend '$name' -> port $backendPort; proxy -> $proxyPort (BASE=$base)")

        val cmd = listOf(
            "env",
            "BASE=${baseDir.absolutePath}",
            "BACKENDS=$name",
            "PORT_${name.uppercase()}=$backendPort",
            "PROXY_PORT=$proxyPort",
            "$harnessBin/dev-network.sh",
        )
        val proc = ProcessBuilder(cmd)
            .directory(project.rootProject.projectDir)
            .inheritIO()
            .start()
        proc.waitFor()
        if (proc.exitValue() != 0 && proc.exitValue() != 130) {
            throw GradleException("dev network exited with code ${proc.exitValue()}")
        }
    }
}