module docker_man;
import io  = std.stdio;
import sp  = std.process; 
import opt = std.getopt;
import sf  = std.file;
import std.conv;
import std.algorithm;

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

        bool dont_remove_container = false;

        opt.GetoptResult opt_result;

        try {
                opt_result = opt.getopt(
                                args
                                ,"verbose",      "Log docker commands for debugging.", &verbose
                                ,"w|workdir",    "Working directory, default current directory of host.", &workdir
                                ,"n|name",       "Human-readable name for container." ,&name
                                ,"c|command",    "Command to be executed by image entrypoint", &command
                                ,"e|entrypoint", "Alternative entrypoint.", &entrypoint
                                ,"x|x11",        "Enable X11 GUI graphical user interface", &x11
                                ,"u|user",       "Alternative user.", &user
                                ,"m|home",       "Mount $HOME directory to /uhome dir. in container." ,&home                                
                                ,"v|volume",     "Volume to be mounted.", &volumes
                                /* ,"r|drmc",       "Dont remove container (default false)", &dont_remove_container */
                        );

                if (opt_result.helpWanted)
                {
                
                        io.writeln(" dkman - Docker Manager Tool");
                        io.writeln("Usage: $ dkman <SUBCOMMAND> <DOCKER-IMAGE> [<OPTIONS>...]");
                        
                        io.writeln("\n => Run docker-image unix shell (REPL) or any other entrypoint.");
                        io.writeln(" $ dkman shell <DOCKER-IMAGE> [<OPTIONS>...] ");
                        
                        io.writeln("\n => Run docker-image as daemon (aka service) ");
                        io.writeln(" $ dkman daemon <DOCKER-IMAGE> [<OPTIONS>...] ");                        

                        io.writeln("\n => Build docker image from file ");
                        io.writeln(" $ dkman build <DOCKER-IMAGE=-NAME> <DOCKER-FILE>");                        


                        opt.defaultGetoptPrinter("\n Options:", opt_result.options);
                        // Exit main() function 
                        return; 
                }
                
                /+ auto arglist = args.filter!((string x) => !startsWith(x, "-"));
                io.writeln(" arglist = ", arglist);
                 +/       
                if(args.length < 3) {
                        io.writeln("Erro: expected <COMMAND> <DOCKER-IMAGE> arguments.");
                        return;
                }

                if(args[1] == "shell")  
                        docker_shell( args[2], workdir, entrypoint, command, user, name
                                        , home, x11, verbose, false, false, volumes);        
                
                if(args[1] == "daemon"){ 
                        bool flag_dont_remove_container = name != null;
                        docker_shell( args[2], workdir, entrypoint, command, user, name
                                        , home, x11, verbose, true
                                        , flag_dont_remove_container, volumes);        
                }
                
                if(args[1] == "build")
                        build_docker_image(args[2], args[3]);

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

void docker_shell(  string docker_image
                      , string workdir      = null 
                      , string entrypoint   = null 
                      , string command      = null 
                      , string user         = null 
                      , string name         = null 
                      , bool enable_home    = false
                      , bool enable_x11     = false
                      , bool enable_verbose = false 
                      , bool enable_daemon  = false
                      , bool dont_remove_container = false
                      , string[] volumes    = []
                     )
{
        auto docker_args = ["docker", "run", "-it"]; 

        // Get current directory 
        string cwd = sf.getcwd();
        // Get home directory 
        string home = sp.environment.get("HOME");

        if( !dont_remove_container ) docker_args ~= ["--rm"];

        if(enable_daemon) docker_args ~= ["--detach"];

        if(user != null){
                if(enable_verbose) io.writefln(" [TRACE] User changed to: '%s'", user);
                docker_args ~= ["--user", user];
        }        

        if(name != null){
                docker_args ~= ["--name", name];
        }

        // Directory to be mounted to '/work' dir in container. 
        string wdir = workdir != null ? workdir : cwd;

        if(enable_verbose) io.writefln(" [TRACE] Mount %s to /work ", wdir);
        // Concatenate list 
        docker_args ~= ["-v", wdir ~ ":/work"];
        // Set /work as current directory in container 
        docker_args ~= ["-w", "/work"];
        
        if(enable_verbose) io.writefln(" [TRACE] Mount %s to /uhome ", home);
        if(enable_home) docker_args ~= ["-v", home ~ ":/uhome"];

        if(enable_x11) {
                if(enable_verbose) io.writefln(" [TRACE] Enable X11 - graphical user interfaces ");
                sp.executeShell("xhost +local:docker");
                docker_args ~= ["-e", "DISPLAY"];
                docker_args ~= ["-v", "/tmp/.X11-unix:/tmp/.X11-unix"];
                docker_args ~= ["-v", home ~ "/.Xauthority:/root/.Xauthority"];
        }

        if(entrypoint != null) {
                if(enable_verbose) io.writefln(" [TRACE] Entrypoint changed to: %s", entrypoint);
                docker_args ~= ["--entrypoint=" ~ entrypoint];
        }

        
        foreach (v; volumes)
        {                        
                //assert(v.split(":").length != 2);
                docker_args ~= ["-v", v];
        }
        
        docker_args ~= [ docker_image ];

        if(command != null) docker_args ~= [ command ];

        if(enable_verbose) io.writeln(" Docker command run: \n ", docker_args);

        auto d1 = sp.spawnProcess(docker_args);            
        sp.wait(d1);
}

void build_docker_image(string image_name, string docker_file)
{
        auto docker_args = [ "docker", "build", "-f", docker_file, "-t", image_name, "."];
        auto d1 = sp.spawnProcess(docker_args);            
        sp.wait(d1);
}