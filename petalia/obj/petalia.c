
#include <getopt.h>
#include <libgen.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define PREFIX "/Applications/petalia.app/Contents/MacOS"
#define BUFFER_SIZE BUFSIZ
#define ERR_PREFIX "error:"

void p_usage(const char *cl) {
  fprintf(stderr, "petalia - The macOS Wallpaper Manager\n\
Usage: %s [ OPTION ] [ FILE ] ...\n\n\
Options:\n\
    --set [ FILE ]          set FILE (.mov, .mp4, .gif) as wallpaper\n\
    --unset                 unset current wallpaper\n\
    --persist               enables wallpaper persistence across logins/reboots\n\
    --volume [ 0-100 ]      set wallpaper volume (0-100)\n\
    --help                  show this help message\n\n\
Examples:\n\
    %s --set ~/Downloads/hornet.gif\n\
    %s --persist\n\
    %s --volume 50\n\n\
    This tool is only useful for moving wallpapers!",
          cl, cl, cl, cl);
}

int n_la(const char *wp_img) {
  char *home = getenv("HOME");

  char launch_agent[BUFFER_SIZE];
  snprintf(launch_agent, sizeof(launch_agent),
           "%s/Library/LaunchAgents/com.naomisphere.petalia.wallpaper.plist",
           home);

  FILE *agent_file = fopen(launch_agent, "w");
  if (!agent_file) {
    perror("Failed to create LaunchAgent plist");
    system("echo 'APP: failed to create LaunchAgent plist (wallpaper will not "
           "persist)' >> /tmp/petalia.log");
    return 1;
  }

  char gwp_bin[BUFFER_SIZE];
  uint32_t size = sizeof(gwp_bin);
  if (_NSGetExecutablePath(gwp_bin, &size) == 0) {
    char *dir = dirname(gwp_bin);
    snprintf(gwp_bin, sizeof(gwp_bin),
             "%s/petalia Wallpaper Service (glasswp)", dir);
  } else {
    snprintf(gwp_bin, sizeof(gwp_bin),
             "/Applications/petalia.app/Contents/MacOS/petalia Wallpaper "
             "Service (glasswp)");
  }

  fprintf(agent_file,
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
          "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
          "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
          "<plist version=\"1.0\">\n"
          "<dict>\n"
          "    <key>Label</key>\n"
          "    <string>com.naomisphere.petalia.wallpaper</string>\n"
          "    <key>ProgramArguments</key>\n"
          "    <array>\n"
          "        <string>%s</string>\n"
          "        <string>%s</string>\n"
          "    </array>\n"
          "    <key>RunAtLoad</key>\n"
          "    <true/>\n"
          "    <key>KeepAlive</key>\n"
          "    <false/>\n"
          "    <key>StandardOutPath</key>\n"
          "    <string>/tmp/petalia.log</string>\n"
          "    <key>StandardErrorPath</key>\n"
          "    <string>/tmp/petalia.log</string>\n"
          "</dict>\n"
          "</plist>",
          gwp_bin, wp_img);

  fclose(agent_file);

  /*
  char lctl_load[BUFFER_SIZE * 2];
  snprintf(lctl_load, sizeof(lctl_load), "launchctl load \"%s\"", launch_agent);

  printf("\nwallpaper will now start automatically on login.\n");
  printf("to disable this, run:\n");
  printf("launchctl disable gui/$UID/com.naomisphere.petalia.wallpaper\n");
  printf("(to undo, enable again or re-run petalia)\n");
  */
  return 0;
}

int upa_off(const char *type) {
  char *home = getenv("HOME");
  char launch_agent[BUFFER_SIZE];
  snprintf(launch_agent, sizeof(launch_agent),
           "%s/Library/LaunchAgents/com.naomisphere.petalia.%s.plist", home,
           type);

  char lctl_unload[BUFFER_SIZE * 2];
  snprintf(lctl_unload, sizeof(lctl_unload),
           "launchctl unload \"%s\" 2>/dev/null", launch_agent);
  system(lctl_unload);

  remove(launch_agent);

  printf("%s persistence disabled.\n", type);
  return 0;
}

int set_wp(const char *wp_img) {
  char glasswp[BUFFER_SIZE];
  char *home = getenv("HOME");
  

  char _wp[BUFFER_SIZE];
  snprintf(_wp, sizeof(_wp), "%s/.local/share/petalia/current_wallpaper",
           home);
  FILE *wp_file = fopen(_wp, "w");
  if (wp_file) {
    fprintf(wp_file, "%s\n", wp_img);
    fclose(wp_file);
  }

  upa_off("wallpaper");
  system("pkill -9 -f 'petalia Wallpaper Service (glasswp)' 'glasswp' "
         "'glasswp*' 2>/dev/null || true");

  char user_wp[BUFFER_SIZE];
  snprintf(user_wp, sizeof(user_wp), "%s/petalia Wallpaper Service (glasswp)",
           PREFIX);

  char cmd[BUFFER_SIZE];
  snprintf(cmd, sizeof(cmd), "pkill -9 -f '%s' 2>/dev/null || true", user_wp);
  system(cmd);

  
  
  system("pkill -9 -f 'petalia.*Wallpaper.*Service' 2>/dev/null || true");
  system("pkill -9 -f 'glasswp' 2>/dev/null || true");

  uint32_t size = sizeof(glasswp);
  if (_NSGetExecutablePath(glasswp, &size) == 0) {
    char *dir = dirname(glasswp);
    snprintf(glasswp, sizeof(glasswp),
             "%s/petalia Wallpaper Service (glasswp)", dir);
  } else {
    snprintf(glasswp, sizeof(glasswp),
             "%s/petalia Wallpaper Service (glasswp)", PREFIX);
  }

  pid_t pid = fork();
  if (pid == 0) {
    execl(glasswp, glasswp, wp_img, NULL);
    perror("Failed to start wallpaper service");
    _exit(1);
  } else if (pid > 0) {
    char _wp[BUFFER_SIZE];
    printf("wallpaper service started with PID %d\n", pid);
    printf("use --persist to create persistence launchagent\n");
    snprintf(_wp, sizeof(_wp), "%s/.local/share/petalia/current_wallpaper",
             home);

    FILE *file = fopen(_wp, "w");
    if (file) {
      fprintf(file, "%s\n", wp_img);
      fclose(file);
    }

    return 0;
  } else {
    perror("failed to fork");
    return 1;
  }
}

int set_volume(const char *volume_str) {
  int volume = atoi(volume_str);

  if (volume < 0 || volume > 100) {
    fprintf(stderr, "volume must be 0-100\n");
    return 1;
  }

  char *home = getenv("HOME");
  if (!home) {
    fprintf(stderr, "no home variable?\n");
    return 1;
  }

  char volume_file[BUFFER_SIZE];
  snprintf(volume_file, sizeof(volume_file), "%s/.local/share/petalia/volume",
           home);

  char dir_cmd[BUFFER_SIZE];
  snprintf(dir_cmd, sizeof(dir_cmd), "mkdir -p %s/.local/share/petalia", home);
  system(dir_cmd);

  FILE *vol_file = fopen(volume_file, "w");
  if (!vol_file) {
    perror("couldn't to write volume file");
    return 1;
  }

  fprintf(vol_file, "%d\n", volume);
  fclose(vol_file);

  printf("Volume set to %d%%\n", volume);
  return 0;
}

int unset_wp() {
  char user_wp[BUFFER_SIZE];
  char *home = getenv("HOME");
  char _wp[BUFFER_SIZE];
  char cmd[BUFFER_SIZE];

  system("pkill -f 'petalia Wallpaper Service' 2>/dev/null || true");
  snprintf(user_wp, sizeof(user_wp), "%s/petalia Wallpaper Service (glasswp)",
           PREFIX);
  snprintf(cmd, sizeof(cmd), "pkill -f '%s' 2>/dev/null || true", user_wp);
  system(cmd);

  upa_off("wallpaper");
  snprintf(_wp, sizeof(_wp), "%s/.local/share/petalia/current_wallpaper",
           home);
  remove(_wp);

  printf("wallpaper unset.\n");
  return 0;
}

int disable_persistence_only() {
  char *home = getenv("HOME");
  char launch_agent[BUFFER_SIZE];
  snprintf(launch_agent, sizeof(launch_agent),
           "%s/Library/LaunchAgents/com.naomisphere.petalia.wallpaper.plist",
           home);

  char lctl_unload[BUFFER_SIZE * 2];
  snprintf(lctl_unload, sizeof(lctl_unload),
           "launchctl unload \"%s\" 2>/dev/null", launch_agent);
  system(lctl_unload);

  if (remove(launch_agent) == 0) {
    printf("thou shall not persist!\n");
  }

  return 0;
}

int main(int argc, char *argv[]) {
  if (argc < 2) {
    p_usage(argv[0]);
    return 1;
  }

  static struct option main_args[] = {{"set", required_argument, 0, 's'},
                                      {"unset", no_argument, 0, 'u'},
                                      {"persist", no_argument, 0, 'p'},
                                      {"nopersist", no_argument, 0, 'n'},
                                      {"volume", required_argument, 0, 'v'},
                                      {"help", no_argument, 0, 'h'},
                                      {0, 0, 0, 0}};

  int l = 0;
  int c = getopt_long(argc, argv, "s:upnv:h", main_args, &l);

  switch (c) {
  case 's':
    return set_wp(optarg);

  case 'u':
    return unset_wp();

  case 'p': {
    char *home = getenv("HOME");
    char current_wp[BUFFER_SIZE];
    char _wp[BUFFER_SIZE];
    snprintf(_wp, sizeof(_wp), "%s/.local/share/petalia/current_wallpaper",
             home);
    FILE *wp_file = fopen(_wp, "r");
    if (wp_file && fgets(current_wp, sizeof(current_wp), wp_file)) {
      current_wp[strcspn(current_wp, "\n")] = 0;
      if (strlen(current_wp) > 0 && access(current_wp, F_OK) != -1) {
        if (n_la(current_wp) == 0) {
          printf("persistence enabled for wallpaper\n");
        } else {
          printf("failed to enable persistence\n");
        }
      } else {
        printf("no valid wallpaper path found or file doesn't exist\n");
      }
      fclose(wp_file);
    } else {
      printf("no wallpaper is configured\n");
    }
    return 0;
  }
  case 'v':
    return set_volume(optarg);

  case 'h':
    p_usage(argv[0]);
    return 0;

  case '?':
  default:
    p_usage(argv[0]);
    return 1;
  }
}