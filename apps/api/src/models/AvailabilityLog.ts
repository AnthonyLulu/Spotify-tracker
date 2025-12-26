import { Schema, model, type InferSchemaType } from "mongoose";

const availabilityLogSchema = new Schema(
  {
    eventId: { type: Schema.Types.ObjectId, ref: "Event", required: true, index: true },
    checkedAt: { type: Date, required: true, default: () => new Date(), index: true },
    available: { type: Boolean, required: true }
  },
  { timestamps: true }
);

// query perf: derniers logs d'un event
availabilityLogSchema.index({ eventId: 1, checkedAt: -1 });

export type AvailabilityLogDoc = InferSchemaType<typeof availabilityLogSchema>;
export const AvailabilityLog = model("AvailabilityLog", availabilityLogSchema);
