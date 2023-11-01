const { GitHub, context } = require('@actions/github');

var vars = [];
(async () => {
    const fetc = (await fetch("https://chromiumdash.appspot.com/fetch_releases?channel=Stable&num=1&offset=0").then(x => x.json())).filter(x => x.platform === "Win32" || x.platform === "Windows" || x.platform === "Mac" || x.platform === "Linux" || x.platform === "iOS" || x.platform === "Android").map(x => x.hashes.v8).filter((value, index, array) => array.indexOf(value) === index);
    for (const key in fetc) {
        const res = (await fetch("https://chromium.googlesource.com/v8/v8.git/+/" + fetc[key]).then(x => x.text()));
        vars.push(res.substring(res.indexOf("Version") + 8, res.indexOf("Change-Id:")).trim())
    }
})().then(() => {
    const ver = vars.map(a => a.split('.').map(n => +n + 100000).join('.')).sort().map(a => a.split('.').map(n => +n - 100000).join('.'))[1];
    new GitHub(process.env.GITHUB_TOKEN).repos.createRelease({
      owner: context.repo.owner,
      repo: context.repo.repo,
      tag_name: ver,
      name: `V8 Build (${ver})`,
      draft: false,
      prerelease: true,
      target_commitish: context.sha
    });
})
