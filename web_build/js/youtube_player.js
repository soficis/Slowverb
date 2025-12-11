/**
 * YouTube IFrame Player API Wrapper for Slowverb Web
 * 
 * This module provides a bridge between Flutter/Dart and YouTube's IFrame Player API.
 * Due to CORS/DRM restrictions, audio processing is NOT possible - this provides
 * visualizer sync only.
 */

// Initialize YouTube API
let ytPlayer = null;
let ytPlayerReady = false;
let ytPlaybackCallback = null;
let ytTimeUpdateCallback = null;
let ytTimeUpdateInterval = null;

// Load YouTube IFrame API
function loadYouTubeAPI() {
    return new Promise((resolve, reject) => {
        if (window.YT && window.YT.Player) {
            resolve();
            return;
        }

        const tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';
        tag.onerror = () => reject(new Error('Failed to load YouTube API'));

        const firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

        // YouTube API calls this when ready
        window.onYouTubeIframeAPIReady = () => {
            console.log('[Slowverb] YouTube IFrame API ready');
            resolve();
        };
    });
}

// Initialize player with video ID
async function initYouTubePlayer(videoId, containerId) {
    try {
        await loadYouTubeAPI();

        // Destroy existing player if any
        if (ytPlayer) {
            ytPlayer.destroy();
            ytPlayer = null;
            ytPlayerReady = false;
        }

        // Clear time update interval
        if (ytTimeUpdateInterval) {
            clearInterval(ytTimeUpdateInterval);
            ytTimeUpdateInterval = null;
        }

        return new Promise((resolve, reject) => {
            ytPlayer = new YT.Player(containerId, {
                videoId: videoId,
                height: '100%',
                width: '100%',
                playerVars: {
                    autoplay: 0,
                    controls: 1,
                    modestbranding: 1,
                    rel: 0,
                    fs: 1,
                    playsinline: 1,
                },
                events: {
                    onReady: (event) => {
                        ytPlayerReady = true;
                        console.log('[Slowverb] YouTube player ready');

                        // Start time update interval for visualizer sync
                        ytTimeUpdateInterval = setInterval(() => {
                            if (ytPlayerReady && ytPlayer && ytTimeUpdateCallback) {
                                const currentTime = ytPlayer.getCurrentTime();
                                const duration = ytPlayer.getDuration();
                                const state = ytPlayer.getPlayerState();
                                ytTimeUpdateCallback(currentTime, duration, state);
                            }
                        }, 50); // 20fps for smooth visualizer

                        resolve({ success: true, duration: ytPlayer.getDuration() });
                    },
                    onStateChange: (event) => {
                        if (ytPlaybackCallback) {
                            ytPlaybackCallback(event.data);
                        }
                    },
                    onError: (event) => {
                        console.error('[Slowverb] YouTube player error:', event.data);
                        reject(new Error(`YouTube error code: ${event.data}`));
                    }
                }
            });
        });
    } catch (error) {
        console.error('[Slowverb] Failed to initialize YouTube player:', error);
        throw error;
    }
}

// Playback controls
function playYouTube() {
    if (ytPlayer && ytPlayerReady) {
        ytPlayer.playVideo();
        return true;
    }
    return false;
}

function pauseYouTube() {
    if (ytPlayer && ytPlayerReady) {
        ytPlayer.pauseVideo();
        return true;
    }
    return false;
}

function seekYouTube(seconds) {
    if (ytPlayer && ytPlayerReady) {
        ytPlayer.seekTo(seconds, true);
        return true;
    }
    return false;
}

function getYouTubeCurrentTime() {
    if (ytPlayer && ytPlayerReady) {
        return ytPlayer.getCurrentTime();
    }
    return 0;
}

function getYouTubeDuration() {
    if (ytPlayer && ytPlayerReady) {
        return ytPlayer.getDuration();
    }
    return 0;
}

function getYouTubeState() {
    if (ytPlayer && ytPlayerReady) {
        return ytPlayer.getPlayerState();
    }
    return -1; // Unstarted
}

function destroyYouTubePlayer() {
    if (ytTimeUpdateInterval) {
        clearInterval(ytTimeUpdateInterval);
        ytTimeUpdateInterval = null;
    }
    if (ytPlayer) {
        ytPlayer.destroy();
        ytPlayer = null;
        ytPlayerReady = false;
    }
}

// Register callbacks from Dart
function setYouTubePlaybackCallback(callback) {
    ytPlaybackCallback = callback;
}

function setYouTubeTimeUpdateCallback(callback) {
    ytTimeUpdateCallback = callback;
}

// Parse video ID from various YouTube URL formats
function parseYouTubeVideoId(url) {
    const regexes = [
        /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/v\/)([a-zA-Z0-9_-]{11})/,
        /^([a-zA-Z0-9_-]{11})$/, // Direct video ID
    ];

    for (const regex of regexes) {
        const match = url.match(regex);
        if (match && match[1]) {
            return match[1];
        }
    }
    return null;
}

// Export to global scope for Dart interop
window.SlowverbYouTube = {
    init: initYouTubePlayer,
    play: playYouTube,
    pause: pauseYouTube,
    seek: seekYouTube,
    getCurrentTime: getYouTubeCurrentTime,
    getDuration: getYouTubeDuration,
    getState: getYouTubeState,
    destroy: destroyYouTubePlayer,
    setPlaybackCallback: setYouTubePlaybackCallback,
    setTimeUpdateCallback: setYouTubeTimeUpdateCallback,
    parseVideoId: parseYouTubeVideoId,

    // YouTube player state constants
    UNSTARTED: -1,
    ENDED: 0,
    PLAYING: 1,
    PAUSED: 2,
    BUFFERING: 3,
    CUED: 5,
};

console.log('[Slowverb] YouTube player wrapper loaded');
