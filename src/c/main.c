#define MAX_CHAR_IN_LINE 60
#define MAX_LINE 17
// Output ports
#define SET_X_PORT 2
#define SET_Y_PORT 4
#define AUDIO_CONTROLLER_OUTPUT 8
#define PLAY_NAME 16
#define DELETE_NAME 32


// Input ports
#define KEY_PAD_PORT 1
#define AUDIO_CONTROLLER_INPUT 2
#define PLAY_PAUSE_BUTTON 4
#define STOP_BUTTON 8
#define RECORDING_STOPRECORDING_BUTTON 16


// Macro for input/output values
// Keypad
#define KEY_PAD_1 17
#define KEY_PAD_2 18
#define KEY_PAD_3 20
#define KEY_PAD_4 33
#define KEY_PAD_5 34
#define KEY_PAD_6 36
#define KEY_PAD_7 65
#define KEY_PAD_8 66
#define KEY_PAD_9 68
#define KEY_PAD_0 129
#define KEY_PAD_ENTER 136

// audio controller output
#define PLAY_MODE 1
#define PLAY_PAUSE 2
#define STOP 4
#define RECORDING_MODE 8
#define RECORDING_STOPRECORDING 16
#define DELETING_MODE 32
#define DELETING_ALL 64

// audio controller input
#define PLAY_FINISHED 1
#define RECORDING_SUCCESS 2
#define DELETED_SUCCESS 4




int delay_1s() {
    for (int i = 255; i > 0; i = i - 1) {
        for (int j = 255; j > 0; j = j - 1) {
            for (int k = 255; k > 0; k = k - 1) {
                __psm__("LOAD s0, s0");
                __psm__("LOAD s0, s0");
                __psm__("LOAD s0, s0");
                __psm__("LOAD s0, s0");
                __psm__("LOAD s0, s0");
                __psm__("LOAD s0, s0");
            }
        }
    }
}

int delay(int seconds) {
    for (int i = 0; i < seconds; i = i + 1) {
        delay_1s();
    }
}

int clean_screen() {
    output(0, SET_X_PORT);
    output(0, SET_Y_PORT);
    for (int i = 0; i < MAX_LINE; i = i + 1) {
        for (int j = 0; j < MAX_CHAR_IN_LINE; j = j + 1) {
            print(" ");
        }
    }
}

int print_menu() {
    print("1. Play a recording\n");
    print("2. Record\n");
    print("3. Delete a message\n");
    print("4. Delete all messages\n");
    print("Configure the volume via the switches onboard.\n");
}

int main() {
    clean_screen();
    int state = 0;
    int current_number_of_recordings = 0;
    // 0: Show menu; 1: Play recording; 2: Record a message; 3. Delete a message; 4. Delete all messages;
    while (1) {
        // Menu
        clean_screen();
        if (state == 0) {
            print_menu();
            int keypad_input = input(KEY_PAD_PORT);
            while (keypad_input == 0) {
                keypad_input = input(KEY_PAD_PORT);
            }
            if (keypad_input != 0) {
                if (keypad_input == KEY_PAD_1) {
                    state = 1;
                }
                else if (keypad_input == KEY_PAD_2) {
                    state = 2;
                }
                else if (keypad_input == KEY_PAD_3) {
                    state = 3;
                }
                else if (keypad_input == KEY_PAD_4) {
                    state = 4;
                }
            }
        }
        else if (state == 1) {
            clean_screen();
            if (current_number_of_recordings == 0) {
                print("Please record at least 1 recording to use this function. Terminating...");
                delay(3);
                state = 0;
            }
            else {
                int recording_name = 0;
                int digit_entered = 0;
                print("What recording you want to play?\nRecording naming starts at 0\nUse numpad to enter the recording name.\nTwo digits allowed\n");
                int keypad_input = input(KEY_PAD_PORT);
                while (keypad_input != KEY_PAD_ENTER && digit_entered < 2) {
                    if (keypad_input == KEY_PAD_0) {
                        recording_name = recording_name*10;
                        digit_entered = digit_entered + 1;
                        print("0");
                    }
                    else if (keypad_input == KEY_PAD_1) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 1;
                        digit_entered = digit_entered + 1;
                        print("1");
                    }
                    else if (keypad_input == KEY_PAD_2) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 2;
                        digit_entered = digit_entered + 1;
                        print("2");
                    }
                    else if (keypad_input == KEY_PAD_3) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 3;
                        digit_entered = digit_entered + 1;
                        print("3");
                    }
                    else if (keypad_input == KEY_PAD_4) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 4;
                        digit_entered = digit_entered + 1;
                        print("4");
                    }
                    else if (keypad_input == KEY_PAD_5) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 5;
                        digit_entered = digit_entered + 1;
                        print("5");
                    }
                    else if (keypad_input == KEY_PAD_6) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 6;
                        digit_entered = digit_entered + 1;
                        print("6");
                    }
                    else if (keypad_input == KEY_PAD_7) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 7;
                        digit_entered = digit_entered + 1;
                        print("7");
                    }
                    else if (keypad_input == KEY_PAD_8) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 8;
                        digit_entered = digit_entered + 1;
                        print("8");
                    }
                    else if (keypad_input == KEY_PAD_9) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 9;
                        digit_entered = digit_entered + 1;
                        print("9");
                    }
                    keypad_input = input(KEY_PAD_PORT);
                }
                if (digit_entered == 0) {
                    print("\nPlaying the first song");
                    output(PLAY_NAME, 0);
                    output(AUDIO_CONTROLLER_OUTPUT, PLAY_MODE);
                    int play = 1;
                    int play_status = input(AUDIO_CONTROLLER_OUTPUT);
                    while (play_status != PLAY_FINISHED) {
                        int play_pause_button = input(PLAY_PAUSE_BUTTON);
                        int stop_button = input(STOP_BUTTON);
                        if (stop_button) {
                            output(AUDIO_CONTROLLER_OUTPUT, STOP);
                        }
                        if (play_pause_button == 1) {
                            if (play == 0) {
                                play = 1;
                                output(AUDIO_CONTROLLER_OUTPUT, PLAY_PAUSE);
                            }
                            else {
                                play = 0;
                                output(AUDIO_CONTROLLER_OUTPUT, PLAY_PAUSE);
                            }
                        }
                        play_status = input(AUDIO_CONTROLLER_OUTPUT);
                    }
                    print("\nFinished. Returning to the main menu...");
                    state = 0;
                }
                else if (recording_name >= 32) {
                    print("\nInvalid song name: Out of range. Returning to the menu\n");
                    delay(3);
                    state = 0;
                }
                else {
                    print("\nPlaying...");
                    output(PLAY_NAME, recording_name);
                    output(AUDIO_CONTROLLER_OUTPUT, PLAY_MODE);
                    int play = 1;
                    int play_status = input(AUDIO_CONTROLLER_OUTPUT);
                    while (play_status != PLAY_FINISHED) {
                        int play_pause_button = input(PLAY_PAUSE_BUTTON);
                        int stop_button = input(STOP_BUTTON);
                        if (stop_button) {
                            output(AUDIO_CONTROLLER_OUTPUT, STOP);
                        }
                        if (play_pause_button == 1) {
                            if (play == 0) {
                                play = 1;
                                output(AUDIO_CONTROLLER_OUTPUT, PLAY_PAUSE);
                            }
                            else {
                                play = 0;
                                output(AUDIO_CONTROLLER_OUTPUT, PLAY_PAUSE);
                            }
                        }
                        play_status = input(AUDIO_CONTROLLER_OUTPUT);
                    }
                    print("\nFinished. Returning to the main menu...");
                    state = 0;
                }
            }
        }
        else if (state == 2) {
            clean_screen();
            if (current_number_of_recordings == 32) {
                print("No more memory. Returning to the menu");
                delay(3);
                state = 0;
            }
            else {
                print("Recording...\n");
                output(AUDIO_CONTROLLER_OUTPUT, RECORDING_MODE);
                int recording_status = input(AUDIO_CONTROLLER_INPUT);
                while (recording_status != RECORDING_SUCCESS) {
                    int stop_recording = input(RECORDING_STOPRECORDING_BUTTON);
                    if (stop_recording) {
                        output(AUDIO_CONTROLLER_OUTPUT, RECORDING_STOPRECORDING);
                    }
                }
                print("Recorded. Returning to the menu...");
                current_number_of_recordings = current_number_of_recordings + 1;
                state = 0;
                delay(3);
            }
        }
        else if (state == 3) {
            clean_screen();
            if (current_number_of_recordings == 0) {
                print("Nothing to delete. Returning to the main menu...");
                delay(3);
                state = 0;
            }
            else {
                output(AUDIO_CONTROLLER_OUTPUT, DELETING_MODE);
                int recording_name = 0;
                int digit_entered = 0;
                print("What recording you want to delete?\nRecording naming starts at 0\nUse numpad to enter the recording name.\nTwo digits allowed\n");
                int keypad_input = input(KEY_PAD_PORT);
                while (keypad_input != KEY_PAD_ENTER && digit_entered < 2) {
                    if (keypad_input == KEY_PAD_0) {
                        recording_name = recording_name*10;
                        digit_entered = digit_entered + 1;
                        print("0");
                    }
                    else if (keypad_input == KEY_PAD_1) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 1;
                        digit_entered = digit_entered + 1;
                        print("1");
                    }
                    else if (keypad_input == KEY_PAD_2) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 2;
                        digit_entered = digit_entered + 1;
                        print("2");
                    }
                    else if (keypad_input == KEY_PAD_3) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 3;
                        digit_entered = digit_entered + 1;
                        print("3");
                    }
                    else if (keypad_input == KEY_PAD_4) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 4;
                        digit_entered = digit_entered + 1;
                        print("4");
                    }
                    else if (keypad_input == KEY_PAD_5) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 5;
                        digit_entered = digit_entered + 1;
                        print("5");
                    }
                    else if (keypad_input == KEY_PAD_6) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 6;
                        digit_entered = digit_entered + 1;
                        print("6");
                    }
                    else if (keypad_input == KEY_PAD_7) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 7;
                        digit_entered = digit_entered + 1;
                        print("7");
                    }
                    else if (keypad_input == KEY_PAD_8) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 8;
                        digit_entered = digit_entered + 1;
                        print("8");
                    }
                    else if (keypad_input == KEY_PAD_9) {
                        recording_name = recording_name*10;
                        recording_name = recording_name + 9;
                        digit_entered = digit_entered + 1;
                        print("9");
                    }
                    keypad_input = input(KEY_PAD_PORT);
                }
                if (digit_entered == 0) {
                    print("\nNo filename detected. Terminating...");
                    state = 0;
                    delay(3);
                }
                else if (recording_name >= 32) {
                    print("\nNo filename detected. Terminating...");
                    state = 0;
                    delay(3);
                }
                else {
                    output(AUDIO_CONTROLLER_OUTPUT, DELETING_MODE);
                    output(DELETE_NAME, recording_name);
                    print("\nDeleting...\n");
                    int audio_controller_status = input(AUDIO_CONTROLLER_INPUT);
                    while (audio_controller_status != DELETED_SUCCESS) {
                        audio_controller_status = input(AUDIO_CONTROLLER_INPUT);
                    }
                    print("Finished. Terminating...");
                    delay(3);
                    current_number_of_recordings = current_number_of_recordings - 1;
                    state = 0;
                }
            }
        }
        else if (state == 4) {
            clean_screen();
            if (current_number_of_recordings == 0) {
                print("Nothing to delete. Returning to the main menu...");
                delay(3);
                state = 0;
            }
            else {
                print("Are you sure? This operation will delete all files.\n");
                print("Press Enter key to confirm. Press 1 to get back at the menu.\n");
                int key_input = input(KEY_PAD_PORT);
                while (key_input != KEY_PAD_1 && key_input != KEY_PAD_ENTER) {
                    key_input = input(KEY_PAD_PORT);
                }
                if (key_input == KEY_PAD_1) {
                    print("Returning to the menu...");
                    delay(3);
                    state = 0;
                }
                else {
                    output(AUDIO_CONTROLLER_OUTPUT, DELETING_ALL);
                    int delete_status = input(AUDIO_CONTROLLER_INPUT);
                    while (delete_status != DELETED_SUCCESS) {
                        delete_status = input(AUDIO_CONTROLLER_INPUT);
                    }
                    print("Finished deleted all. Returning...");
                    delay(3);
                    state = 0;
                }
            }
        }
    }
}