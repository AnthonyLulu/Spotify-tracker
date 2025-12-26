import { Schema, model, type InferSchemaType } from "mongoose";

const siteSchema = new Schema(
  {
    name: { type: String, required: true, unique: true },
    urlBase: { type: String },
    scrapingPattern: { type: String },
    contactMail: { type: String },
    active: { type: Boolean, default: true }
  },
  { timestamps: true }
);

export type SiteDoc = InferSchemaType<typeof siteSchema>;
export const Site = model("Site", siteSchema);
