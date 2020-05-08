module docker_man;
import io  = std.stdio;
import sp  = std.process; 
import opt = std.getopt;
import sf  = std.file;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

struct DockerOptions {
        // Docker image to be run
        string   docker_image = null;
        // Alternative container's entrypoint
        string   entrypoint = null;
        // Command to be run
        string   command    = null;
        string   user       = null;
        // Container label (name)
        string   name       = null;
        // Directory of host machine to be mounted to /work
        // Initial current working directory of cotainer.
        // The default value is the current directory of host machine.
        string   workdir    = null; 
        // List of volumes to be mounted.
        string[] volumes    = null;
        // Ports to be shared.
        string[] ports      = null;

        //------ Flags ----------//
        // Enable verbosity and demonstrate all docker commands
        bool     verbose    = false;
        // Mount user $HOM directory to /uhome directory
        bool     home       = false;
        // Enable X11 forwarding for GUI - Graphical
        bool     x11        = false;
        // Detach container (run as service or daemon)
        bool     detach     = false;
        // Remove container if true
        bool     remove     = true;
        // Enable privileged mode (useful for GDB)
        bool     privileged = false;
        // Enable GDB (GNU Debugger) usage in Docker containers. 
        bool     gdb        = false;
}

/** Main function is the entry-point of a D-program */
void main(string[] args) 
{               
        bool verbose      = false;
        bool home         = false;
        bool x11          = false;        
        string entrypoint = null;
        string command    = null;
        string user       = null;
        string name       = null;
        string workdir    = null; 
        string[] volumes  = null;
        string[] ports    = null;

        DockerOptions dopts;

        // bool dont_remove_container = false;

        opt.GetoptResult opt_result;

        // string arg_copy = new string[](args.length);
        auto cmd_args = parse_remaining_args(args);
        // io.writeln(" [TRACE] cmd_args = ", cmd_args);

        try {
                opt_result = opt.getopt(
                                args
                                ,"verbose",       "Log docker commands for debugging.", &dopts.verbose
                                ,"w|workdir",     "Working directory, default current directory of host.", &workdir
                                ,"n|name",        "Human-readable name for container." ,&dopts.name
                                ,"c|command",     "Command to be executed by image entrypoint", &dopts.command
                                ,"e|entrypoint",  "Alternative entrypoint.", &dopts.entrypoint
                                ,"x|x11",         "Enable X11 GUI graphical user interface", &dopts.x11
                                ,"u|user",        "Alternative user.", &dopts.user
                                ,"m|home",        "Mount $HOME directory to /uhome dir. in container." ,&dopts.home
                                ,"v|volume",      "Volume to be mounted.", &dopts.volumes
                                ,"p|port",        "Host port to be mapped to container.", &dopts.ports
                                ,"pr|privileged", "Enable privileged mode, useful for GDB", &dopts.privileged
                                ,"g|gdb",         "Enable GDB (GNU Debugger) and PTrace inside docker containers.", &dopts.gdb 
                                /* ,"r|drmc",       "Dont remove container (default false)", &dont_remove_container */
                        );

                if (opt_result.helpWanted || args.length == 1)
                {
                
                        io.writeln(" dockman - Docker Manager Tool\n");
                        io.writeln("Usage: $ dockman <SUBCOMMAND> <DOCKER-IMAGE> [<OPTIONS>...]");
                        
                        io.writeln("\n => Run docker-image unix shell (REPL) or any other entrypoint.");
                        io.writeln("  $ dockman shell <DOCKER-IMAGE> [<OPTIONS>...] ");
                        io.writeln("  $ dockman sh <DOCKER-IMAGE> [<OPTIONS>...] ");
                        
                        io.writeln("\n => Run docker-image as service (aka daemon) ");
                        io.writeln("  $ dockman serive <DOCKER-IMAGE> [<OPTIONS>...] ");                        
                        io.writeln("  $ dockman sr <DOCKER-IMAGE> [<OPTIONS>...] ");                        

                        io.writeln("\n => Build docker image from file ");
                        io.writeln("  $ dockman build <DOCKER-IMAGE-NAME> <DOCKER-FILE>");                        

                        io.writeln("\n => Open shell (bash) in a docker named-volume.");
                        io.writeln("  $ dockman volume-shell <DOCKER-VOLUME-NAME>");                        
                        io.writeln("  $ dockman vs <DOCKER-VOLUME-NAME>");                        

                        opt.defaultGetoptPrinter("\n Options:", opt_result.options);
                        // Exit main() function 
                        return; 
                }

                // io.writeln(" [TRACE] => args = ", args);
                
                if(args[1] == "container-list" || args[1] == "cl")
                {
                        docker_container_list();
                        return;
                }

                dopts.docker_image = args[2];
                dopts.command = join(cmd_args, " ");

                /+ auto arglist = args.filter!((string x) => !startsWith(x, "-"));
                io.writeln(" arglist = ", arglist);
                 +/       
                if(args.length < 3) {
                        io.writeln("Erro: expected <COMMAND> <DOCKER-IMAGE> arguments.");
                        return;
                }

                // Run docker container in interactive mode (tty) or batch mode
                if(args[1] == "shell" || args[1] == "sh")
                        docker_shell( &dopts );                      

                // Run docker container as service (daemon)
                if(args[1] == "service" || args[1] == "sr"){
                        dopts.detach = true;
                        dopts.remove = dopts.name == null;
                        docker_shell( &dopts );        
                }
                
                if(args[1] == "build") {  docker_build(args[2], args[3]); }

                if(args[1] == "volume-shell" || args[1] == "vs") {
                        docker_volume_shell(args[2]);
                }

        } catch (opt.GetOptException) 
        {
                io.writeln(" Error: invalid option. Run with (--help) switch to show usage. ");
                io.writeln(opt_result.options);
        } catch (std.conv.ConvException)
        {
                io.writeln(" Error: invalid option. Run with (--help) switch to show usage. ");
                // io.writeln(opt_result.options);
        }        

} // ------ End of main() ------------- //

string[] parse_remaining_args(string[] args)
{        
        int i = 0;
        foreach (string k; args)
        {       
                if(k == "--") break;
                i++;
        }
        if(i + 1 > args.length) return [];
        auto cp = new string[](args.length - i - 1);
        cp[0..$] = args[(i + 1)..$];
        assert(&cp[0] != &args[i + 1]);
        return cp;
}

void docker_shell(DockerOptions* dpt)
{
        auto docker_args = ["docker", "run", "-it"];

        // Get current directory 
        string cwd = sf.getcwd();
        // Get home directory 
        string home = sp.environment.get("HOME");

        if( dpt.remove ) docker_args ~= ["--rm"];

        
        if(dpt.detach) docker_args ~= ["--detach"];

        if(dpt.user != null){
                // if(enable_verbose) io.writefln(" [TRACE] User changed to: '%s'", user);
                docker_args ~= ["--user", dpt.user];
        }        

        if(dpt.name != null){
                docker_args ~= ["--name", dpt.name];
        }

        if(dpt.privileged) { docker_args ~= ["--privileged"]; }

        // Directory to be mounted to '/work' dir in container. 
        string wdir = dpt.workdir != null ? dpt.workdir : cwd;

        if(dpt.verbose) io.writefln(" [TRACE] Mount %s to /cwd ", wdir);
        // Concatenate list 
        docker_args ~= ["-v", wdir ~ ":/cwd"];
        // Set /work as current directory in container 
        docker_args ~= ["-w", "/cwd"];
                
        if(dpt.home) {
                if(dpt.verbose) io.writefln(" [TRACE] Mount %s to /uhome ", home);
                docker_args ~= ["-v", home ~ ":/uhome"];
        }

        if(dpt.x11) {
                if(dpt.verbose) io.writefln(" [TRACE] Enable X11 - graphical user interfaces ");
                sp.executeShell("xhost +local:docker");
                docker_args ~= ["-e", "DISPLAY"];
                docker_args ~= ["-v", "/tmp/.X11-unix:/tmp/.X11-unix"];
                docker_args ~= ["-v", home ~ "/.Xauthority:/root/.Xauthority"];
        }

        if(dpt.entrypoint != null) {
                if(dpt.verbose) io.writefln(" [TRACE] Entrypoint changed to: %s", dpt.entrypoint);
                docker_args ~= ["--entrypoint=" ~ dpt.entrypoint];
        }

        // Enable GDB inside Docker container (Useful for debugging C, C++, DLang or Rust)
        // Reference: https://leimao.github.io/blog/Debug-CPP-In-Docker-Container/
        if(dpt.gdb) {  docker_args ~= ["--cap-add=SYS_PTRACE", "--security-opt", "seccomp=unconfined" ]; }

        foreach (v; dpt.volumes)
        {                        
                //assert(v.split(":").length != 2);
                string[] s = v.split(":");                
                string src = s[0].replace("./",    cwd ~ "/")
                                 .replace("{PWD}", cwd ~ "/")
                                 .replace("~", home )
                                 .replace("{HOME}", home );
                // io.writeln(" [DEBUG] src = ", src , " v = ", v);
                docker_args ~= ["-v", src ~ ":" ~ s[1] ];
        }

        foreach (p; dpt.ports)
        {
                docker_args ~= ["-p", p];
        }
        
        docker_args ~= [ dpt.docker_image ];

        if(dpt.command != null) docker_args ~= dpt.command.split(" ");
        if(dpt.verbose) io.writeln(" Docker command run: \n ", docker_args);

        auto d1 = sp.spawnProcess(docker_args);            
        sp.wait(d1);
}

/** Mount a named volume to a directory '/volume' in an alpine container 
  * and set the directory /volume as the current working directory. 
  * The current directory of host is mounted to /cwd directory in the container.
  */
void docker_volume_shell(string named_volume)
{
        // Get current directory 
        string cwd = sf.getcwd();

        string proc_read_stdout_line(string[] args) {
                // Get host user's UID 
                auto pipe = sp.pipeProcess(["id", "-u"], sp.Redirect.stdout);
                sp.wait(pipe.pid);
                return  std.string.strip(pipe.stdout.readln(), "\n");                
        }

        const string user_uid = proc_read_stdout_line(["id", "-u"]);
        const string user_gid = proc_read_stdout_line(["id", "-u"]);             

        string[] docker_args = [  "docker", "run", "--rm", "-it"
                                , "-v", cwd ~ ":/cwd"
                                , "-v", named_volume ~ ":/volume"
                                , "-w", "/volume"
                                , "--env", "HOST_UID=" ~ user_uid
                                , "--env", "HOST_GID=" ~ user_gid
                                ,"alpine"
                                ];
        
        //io.writeln(" [TRACE] docker_args = ", docker_args);

        auto d1 = sp.spawnProcess(docker_args);                    
        sp.wait(d1);                                        
}

/** List all containers in a summarized way. */
void docker_container_list()
{
        string[] docker_args = [  "docker", "ps", "-a"
                                , "--format"
                                , "\"table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\""];

        auto d1 = sp.spawnProcess(docker_args);            
        sp.wait(d1);                                        
}

void docker_build(string image_name, string docker_file)
{
        auto docker_args = [ "docker", "build", "-f", docker_file, "-t", image_name, "."];
        auto d1 = sp.spawnProcess(docker_args);            
        sp.wait(d1);
}