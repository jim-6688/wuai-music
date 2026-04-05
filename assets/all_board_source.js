/** 
 * @name 全网榜单音源
 * @description 自动获取QQ音乐、网易云、酷狗、酷我的热门榜单
 * @version 1.0.0
 * @author 吾爱Music
 * @homepage https://github.com/wuaimusic
 */

// ============ 调试：检查 lx 对象 ============
console.log('DEBUG: typeof lx = ' + typeof lx);
console.log('DEBUG: typeof lx.send = ' + typeof lx.send);

// ============ 初始化数据（必须在最开头发送，避免 flutter_js evaluateAsync 延迟） ============
var _allBoardInitData = {
  sources: {
    'all-board': {
      name: '全网榜单',
      type: 'music',
      actions: ['leaderboard', 'leaderboardDetail', 'search', 'musicUrl', 'lyric', 'pic'],
      qualitys: ['128k', '320k', 'flac']
    }
  },
  openDevTools: false
};

// 立即发送初始化（关键：必须在HTTP请求之前！）
console.log('DEBUG: 准备设置 lx._initData');
lx._initData = _allBoardInitData;
console.log('DEBUG: lx._initData 已设置，当前值: ' + (lx._initData ? '有值' : 'null'));

console.log('DEBUG: 准备调用 lx.send');
try {
  lx.send('inited', _allBoardInitData);
  console.log('DEBUG: lx.send 已调用完成');
} catch(e) {
  console.log('DEBUG: lx.send 抛出异常: ' + e);
}

// ============ 榜单数据存储 ============
var _leaderboardCache = {
  qq: [],
  wy: [],
  kg: [],
  kw: [],
  lastUpdate: null
};

// ============ HTTP 请求函数（使用回调，不依赖Promise） ============
function httpGet(url, callback) {
  lx.request(url, {
    method: 'GET',
    timeout: 10000
  }, function(err, data) {
    callback(err, data);
  });
}

// ============ 解析QQ音乐榜单 ============
function parseQQMusicList(data) {
  var list = [];
  try {
    if (typeof data === 'string') {
      var match = data.match(/\{.*\}/);
      if (match) data = JSON.parse(match[0]);
    }
    var songs = data.data || data.songlist || [];
    for (var i = 0; i < songs.length; i++) {
      var s = songs[i];
      list.push({
        id: s.songmid || s.mid || '',
        name: s.songname || s.name || '',
        singer: (s.singer && s.singer[0] && s.singer[0].name) || s.singerName || '',
        album: s.albumname || s.album || '',
        interval: s.interval || 0
      });
    }
  } catch (e) {}
  return list;
}

// ============ 解析网易云榜单 ============
function parseNetEaseList(data) {
  var list = [];
  try {
    var songs = data.playlist && data.tracks || data.songs || [];
    for (var i = 0; i < songs.length; i++) {
      var s = songs[i];
      list.push({
        id: String(s.id),
        name: s.name || '',
        singer: (s.ar && s.ar[0] && s.ar[0].name) || s.artists || '',
        album: (s.al && s.al.name) || s.album || '',
        interval: s.dt || s.duration || 0
      });
    }
  } catch (e) {}
  return list;
}

// ============ 解析酷狗榜单 ============
function parseKugouList(data) {
  var list = [];
  try {
    var songs = data.data && data.data.info || data.songlist || [];
    for (var i = 0; i < songs.length; i++) {
      var s = songs[i];
      list.push({
        id: s.hash || s.audio_id || '',
        name: s.songname || s.name || '',
        singer: s.singername || s.artist || '',
        album: s.album_name || s.album || '',
        interval: s.duration || s.interval || 0
      });
    }
  } catch (e) {}
  return list;
}

// ============ 解析酷我榜单 ============
function parseKuwoList(data) {
  var list = [];
  try {
    var songs = data.musicList || data.songs || [];
    for (var i = 0; i < songs.length; i++) {
      var s = songs[i];
      list.push({
        id: s.rid || s.id || '',
        name: s.name || s.songName || '',
        singer: s.artist || s.singerName || '',
        album: s.album || s.albumName || '',
        interval: s.duration || 0
      });
    }
  } catch (e) {}
  return list;
}

// ============ 获取QQ音乐榜单 ============
function fetchQQMusicLeaderboards() {
  var topList = [
    { id: '4', name: 'QQ音乐巅峰榜·热歌', type: 'hot' },
    { id: '26', name: 'QQ音乐巅峰榜·新歌', type: 'new' },
    { id: '27', name: 'QQ音乐巅峰榜·流行指数', type: 'pop' },
    { id: '62', name: 'QQ音乐巅峰榜·影视金曲', type: 'movie' },
    { id: '63', name: 'QQ音乐巅峰榜·ACG', type: 'acg' }
  ];
  
  var index = 0;
  
  function fetchNext() {
    if (index >= topList.length) {
      return;
    }
    var board = topList[index++];
    var url = 'https://c.y.qq.com/v8/fcg-bin/fcg_v8_toplist_cp.fcg?type=1&topid=' + board.id + '&format=json&json=1';
    
    httpGet(url, function(err, data) {
      if (!err && data) {
        _leaderboardCache.qq.push({
          id: 'qq_' + board.id,
          name: board.name,
          source: 'qq',
          img: 'https://y.gtimg.cn/music/photo_new/T002R300x300M000' + (data.topinfo && data.topinfo.pic_album || '') + '.jpg',
          description: 'QQ音乐' + board.name,
          songs: parseQQMusicList(data)
        });
      } else {
        _leaderboardCache.qq.push({
          id: 'qq_' + board.id,
          name: board.name,
          source: 'qq',
          img: '',
          description: 'QQ音乐' + board.name,
          songs: []
        });
      }
      fetchNext();
    });
  }
  
  fetchNext();
}

// ============ 获取网易云榜单 ============
function fetchNetEaseLeaderboards() {
  var topList = [
    { id: '3778678', name: '网易云音乐·热歌榜', type: 'hot' },
    { id: '3779629', name: '网易云音乐·新歌榜', type: 'new' },
    { id: '2884035', name: '网易云音乐·原创榜', type: 'original' },
    { id: '19723756', name: '网易云音乐·飙升榜', type: 'soar' },
    { id: '10536062', name: '网易云音乐·抖音榜', type: 'douyin' }
  ];
  
  var index = 0;
  
  function fetchNext() {
    if (index >= topList.length) return;
    var board = topList[index++];
    var url = 'https://netease-cloud-music-api-five-roan-25.vercel.app/playlist/detail?id=' + board.id;
    
    httpGet(url, function(err, data) {
      if (!err && data) {
        _leaderboardCache.wy.push({
          id: 'wy_' + board.id,
          name: board.name,
          source: 'wy',
          img: data.playlist && data.playlist.coverImgUrl || '',
          description: '网易云' + board.name,
          songs: parseNetEaseList(data)
        });
      } else {
        _leaderboardCache.wy.push({
          id: 'wy_' + board.id,
          name: board.name,
          source: 'wy',
          img: '',
          description: '网易云' + board.name,
          songs: []
        });
      }
      fetchNext();
    });
  }
  
  fetchNext();
}

// ============ 获取酷狗榜单 ============
function fetchKugouLeaderboards() {
  var listUrl = 'http://mobilecdn.kugou.com/api/v3/rank/list?apiver=4&withsong=1&showtype=2&plat=0&parentid=0&version=8352';
  
  httpGet(listUrl, function(err, data) {
    if (err || !data) {
      _leaderboardCache.kg = [];
      return;
    }
    try {
      var ranks = data.rank && data.rank.list || [];
      var topRanks = ranks.slice(0, 5).map(function(r) {
        return { id: r.rankid, name: r.rankname };
      });
      
      var pending = topRanks.length;
      function checkDone() {
        pending--;
        if (pending <= 0) {
          _leaderboardCache.lastUpdate = new Date().toISOString();
        }
      }
      
      for (var i = 0; i < topRanks.length; i++) {
        var board = topRanks[i];
        var detailUrl = 'http://mobilecdn.kugou.com/api/v3/rank/song?ranktype=0&rankid=' + board.id + '&plat=0&page=1&pagesize=20&version=8352';
        
        httpGet(detailUrl, function(boardInner, err, songData) {
          if (!err && songData) {
            _leaderboardCache.kg.push({
              id: 'kg_' + boardInner.id,
              name: boardInner.name,
              source: 'kg',
              img: songData.imgurl || '',
              description: '酷狗' + boardInner.name,
              songs: parseKugouList(songData)
            });
          } else {
            _leaderboardCache.kg.push({
              id: 'kg_' + boardInner.id,
              name: boardInner.name,
              source: 'kg',
              img: '',
              description: '酷狗' + boardInner.name,
              songs: []
            });
          }
          checkDone();
        }.bind(null, board));
      }
    } catch (e) {
      _leaderboardCache.kg = [];
    }
  });
}

// ============ 获取酷我榜单 ============
function fetchKuwoLeaderboards() {
  var topList = [
    { id: '93', name: '酷我音乐·热歌榜', type: 'hot' },
    { id: '167', name: '酷我音乐·新歌榜', type: 'new' },
    { id: '16', name: '酷我音乐·经典榜', type: 'classic' },
    { id: '58', name: '酷我音乐·欧美榜', type: 'west' },
    { id: '57', name: '酷我音乐·韩语榜', type: 'korean' }
  ];
  
  var index = 0;
  
  function fetchNext() {
    if (index >= topList.length) return;
    var board = topList[index++];
    var url = 'http://search.kuwo.cn/r.s?pn=0&rn=20&type=rank&format=json&response=urlencoded&rid=' + board.id;
    
    httpGet(url, function(err, data) {
      if (!err && data) {
        _leaderboardCache.kw.push({
          id: 'kw_' + board.id,
          name: board.name,
          source: 'kw',
          img: data.pic || '',
          description: '酷我' + board.name,
          songs: parseKuwoList(data)
        });
      } else {
        _leaderboardCache.kw.push({
          id: 'kw_' + board.id,
          name: board.name,
          source: 'kw',
          img: '',
          description: '酷我' + board.name,
          songs: []
        });
      }
      fetchNext();
    });
  }
  
  fetchNext();
}

// ============ 事件处理 ============
lx.on('request', function(params) {
  var action = params.action;
  var info = params.info || {};
  var taskId = params._taskId;
  
  if (action === 'leaderboard') {
    // 返回所有榜单（包括空歌曲的），让用户看到榜单列表
    // 空歌曲的榜单会显示一个加载提示
    var allBoards = [].concat(
      _leaderboardCache.qq,
      _leaderboardCache.wy,
      _leaderboardCache.kg,
      _leaderboardCache.kw
    );
    
    // 检查是否有数据正在加载
    var isLoading = _leaderboardCache.qq.length === 0 && 
                     _leaderboardCache.wy.length === 0 && 
                     _leaderboardCache.kg.length === 0 && 
                     _leaderboardCache.kw.length === 0;
    
    var list = allBoards.map(function(board) {
      return {
        id: board.id,
        name: board.name,
        img: board.img,
        source: board.source,
        description: board.description,
        isLoading: board.songs && board.songs.length === 0  // 标记是否正在加载
      };
    });
    
    // 如果全部为空，返回一个提示
    if (list.length === 0 && isLoading) {
      list = [{
        id: '_loading_',
        name: '正在加载榜单数据...',
        img: '',
        source: 'all-board',
        description: '请稍候，数据获取中'
      }];
    }
    
    setAsyncResult(taskId, list);
    return;
  }
  
  if (action === 'leaderboardDetail') {
    var id = info.id;
    var allBoards = [].concat(
      _leaderboardCache.qq,
      _leaderboardCache.wy,
      _leaderboardCache.kg,
      _leaderboardCache.kw
    );
    
    for (var i = 0; i < allBoards.length; i++) {
      if (allBoards[i].id === id) {
        setAsyncResult(taskId, {
          list: allBoards[i].songs || [],
          updateTime: _leaderboardCache.lastUpdate || '',
          img: allBoards[i].img || '',
          description: allBoards[i].description || ''
        });
        return;
      }
    }
    
    setAsyncResult(taskId, { list: [], updateTime: '' });
    return;
  }
  
  if (action === 'search') {
    setAsyncResult(taskId, { list: [], total: 0 });
    return;
  }
  
  if (action === 'musicUrl') {
    setAsyncError(taskId, '请使用内置音源获取播放链接');
    return;
  }
  
  if (action === 'lyric') {
    setAsyncResult(taskId, { lyric: '', tlyric: '' });
    return;
  }
  
  if (action === 'pic') {
    setAsyncResult(taskId, '');
    return;
  }
  
  setAsyncError(taskId, 'Unknown action: ' + action);
});

// ============ 启动异步获取榜单（在lx.send之后） ============
// 使用 setTimeout(0) 确保 HTTP 请求在初始化完成后才开始
// 这样不会阻塞 evaluateAsync
setTimeout(function() {
  fetchQQMusicLeaderboards();
  fetchNetEaseLeaderboards();
  fetchKugouLeaderboards();
  fetchKuwoLeaderboards();
}, 0);
