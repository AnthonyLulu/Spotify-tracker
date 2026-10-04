const branch="court-boss-live";
const rawBase="https://raw.githubusercontent.com/AnthonyLulu/Spotify-tracker/"+branch+"/court-boss/";
const mime:Record<string,string>={
  html:"text/html; charset=utf-8",
  css:"text/css; charset=utf-8",
  js:"text/javascript; charset=utf-8",
  json:"application/json; charset=utf-8",
  csv:"text/csv; charset=utf-8"
};
const csp="default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data: https:; font-src 'self' data:; base-uri 'self'; frame-ancestors 'none'";

function safeName(value:string){
  const x=decodeURIComponent(value||"").replace(/^\/+|\/+$/g,"");
  if(!x||x==="court-boss-static-publish")return "index.html";
  if(x==="play")return "play.html";
  if(x.includes("..")||x.includes("/")||!/^[-A-Za-z0-9_.]+$/.test(x))return null;
  return x;
}

Deno.serve(async(req:Request)=>{
  const url=new URL(req.url);
  const parts=url.pathname.split("/").filter(Boolean);
  const name=safeName(parts[parts.length-1]||"index.html");

  if(name==="__health"){
    return new Response(JSON.stringify({
      ok:true,
      build:"20261004-intraday-v26",
      branch,
      source:"github-live"
    }),{
      headers:{
        "content-type":"application/json; charset=utf-8",
        "cache-control":"no-store"
      }
    });
  }

  if(!name)return new Response("Bad path",{status:400});

  const upstream=await fetch(rawBase+name,{
    headers:{"user-agent":"court-boss-static-v26"}
  });
  if(!upstream.ok){
    return new Response("Not found",{
      status:404,
      headers:{"cache-control":"no-store"}
    });
  }

  const body=await upstream.arrayBuffer();
  const ext=(name.split(".").pop()||"").toLowerCase();
  const headers=new Headers();
  headers.set("content-type",mime[ext]||upstream.headers.get("content-type")||"application/octet-stream");
  headers.set("cache-control",ext==="html"||ext==="js"?"no-store":"public, max-age=120");
  headers.set("content-security-policy",csp);
  headers.set("x-content-type-options","nosniff");
  headers.set("referrer-policy","no-referrer");
  headers.set("x-court-boss-build","20261004-intraday-v26");

  return new Response(body,{status:200,headers});
});
