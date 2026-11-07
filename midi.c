#include "midi.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

PmStream *midi_output_stream;
MidiOutputDevice *midi_output_devices;

int midi_output_count = 0;
char *midi_output_labels;

void
send_midi_note_on (PmStream *stream, uint8_t note, unsigned int velocity) {
  PmEvent note_on_event;
  note_on_event.message = Pm_Message(NOTE_ON, note, velocity);
  note_on_event.timestamp = 0;
  Pm_WriteShort(stream, 0, note_on_event.message);
}

void
send_midi_note_off (PmStream *stream, uint8_t note) {
  PmEvent note_on_event;
  note_on_event.message = Pm_Message(NOTE_OFF, note, 0);
  note_on_event.timestamp = 0;
  Pm_WriteShort(stream, 0, note_on_event.message);
}

int32_t
list_midi_devices (void) {
  int32_t num_devices = Pm_CountDevices();
  free(midi_output_devices);
  free(midi_output_labels);

  size_t labels_size = strlen("No Output") + 1;
  for (int32_t i = 0; i < num_devices; i++) {
    const PmDeviceInfo *info = Pm_GetDeviceInfo(i);
    if (info->output) labels_size += strlen(info->name) + 1;
  }

  midi_output_devices = malloc(sizeof(MidiOutputDevice) * num_devices);
  midi_output_labels = malloc(labels_size);
  midi_output_count = 0;

  size_t len = snprintf(midi_output_labels, labels_size, "No Output");

  for (int32_t i = 0; i < num_devices; i++) {
    const PmDeviceInfo *info = Pm_GetDeviceInfo(i);
    if (info->output) {
      midi_output_devices[midi_output_count].id = i;
      midi_output_devices[midi_output_count].name = (char *) info->name;
      len += snprintf(midi_output_labels + len, labels_size - len, ";%s", info->name);
      midi_output_count++;
    }
  }
  return midi_output_count;
}
