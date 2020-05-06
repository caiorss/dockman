module docker_man;
import io  = std.stdio;
import sp  = std.process; 
import opt = std.getopt;
import sf  = std.file;
import std.conv;
import std.algorithm;
import std.array;

enum OptionFlags {
        // (bit 0) Enable verbose - Show docker commands 
        verbose = 1 << 0,
        // (bit 1) Mount user $HOME directory to /uhome directory in container 
        home    = 1 << 1,
        // (bit 2) Enable X11 forwarding for displaying GUI applications 
        x11     = 1 << 2,
        // (bit 3) Ennable ptrace capability 
        ptrace  = 1 << 3,
}

bool get_bit_from_flags(int flags, int bit)
{
        return ((flags >> bit) & 1) == 1;
}

struct DockerOptions {
        string   docker_image = null;
        int      flags      = 0;   
        bool     verbose    = false;
        bool     home       = false;
        bool     x11        = false;     
        bool     detach     = false;        
        string   entrypoint = null;
        string   command    = null;
        string   user       = null;
        string   name       = null;
        string   workdir    = null; 
        string[] volumes    = null;
        string[] ports      = null;
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
                                ,"verbose",      "Log docker commands for debugging.", &dopts.verbose
                                ,"w|workdir",    "Working directory, default current directory of host.", &workdir
                                ,"n|name",       "Human-readable name for container." ,&dopts.name
                                ,"c|command",    "Command to be executed by image entrypoint", &dopts.command
                                ,"e|entrypoint", "Alternative entrypoint.", &dopts.entrypoint
                                ,"x|x11",        "Enable X11 GUI graphical user interface", &dopts.x11
                                ,"u|user",       "Alternative user.", &dopts.user
                                ,"m|home",       "Mount $HOME directory to /uhome dir. in container." ,&dopts.home
                                ,"v|volume",     "Volume to be mounted.", &dopts.volumes
                                ,"p|port",       "Host port to be mapped to container.", &dopts.ports
                                /* ,"r|drmc",       "Dont remove container (default false)", &dont_remove_container */
                        );

                if (opt_result.helpWanted || args.length == 1)
                {
                
                        io.writeln(" dockman - Docker Manager Tool\n");
                        io.writeln("Usage: $ dockman <SUBCOMMAND> <DOCKER-IMAGE> [<OPTIONS>...]");
                        
                        io.writeln("\n => Run docker-image unix shell (REPL) or any other entrypoint.");
                        io.writeln(" $ dockman shell <DOCKER-IMAGE> [<OPTIONS>...] ");
                        
                        io.writeln("\n => Run docker-image as daemon (aka service) ");
                        io.writeln(" $ dockman daemon <DOCKER-IMAGE> [<OPTIONS>...] ");                        

                        io.writeln("\n => Build docker image from file ");
                        io.writeln(" $ dockman build <DOCKER-IMAGE=-NAME> <DOCKER-FILE>");                        


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

                if(args[1] == "shell")  
                        docker_shell( &dopts );                      

                if(args[1] == "daemon"){ 
                        bool flag_dont_remove_container = name != null;
                        docker_shell( &dopts );        
                }
                
                if(args[1] == "build")
                        docker_build(args[2], args[3]);                

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
        auto docker_args = ["docker", "run", "-it", "--rm"]; 

        // Get current directory 
        string cwd = sf.getcwd();
        // Get home directory 
        string home = sp.environment.get("HOME");

        //if( !dont_remove_container ) docker_args ~= ["--rm"];

        
        // if(dpt.enable_daemon) docker_args ~= ["--detach"];

        if(dpt.user != null){
                // if(enable_verbose) io.writefln(" [TRACE] User changed to: '%s'", user);
                docker_args ~= ["--user", dpt.user];
        }        

        if(dpt.name != null){
                docker_args ~= ["--name", dpt.name];
        }

        // Directory to be mounted to '/work' dir in container. 
        string wdir = dpt.workdir != null ? dpt.workdir : cwd;

        if(dpt.verbose) io.writefln(" [TRACE] Mount %s to /work ", wdir);
        // Concatenate list 
        docker_args ~= ["-v", wdir ~ ":/work"];
        // Set /work as current directory in container 
        docker_args ~= ["-w", "/work"];
                
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

        
        foreach (v; dpt.volumes)
        {                        
                //assert(v.split(":").length != 2);
                docker_args ~= ["-v", v];
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