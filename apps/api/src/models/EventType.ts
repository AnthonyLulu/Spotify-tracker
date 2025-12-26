import { Schema, model, type InferSchemaType } from "mongoose";

const eventTypeSchema = new Schema(
  {
    name: { type: String, required: true, unique: true }
  },
  { timestamps: true }
);

export type EventTypeDoc = InferSchemaType<typeof eventTypeSchema>;
export const EventType = model("EventType", eventTypeSchema);
