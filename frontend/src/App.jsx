import { useState } from 'react'

const CURRENT_DATE = 'October 27, 2026'
const APP_VERSION = '1.0.0'
const BUILD_NUMBER = '1'
const APK_64 = import.meta.env.VITE_APK_URL_64 || 'https://github.com/Raghul2k4/attendly/releases/download/apk/attendance-1.0.0-arm64-v8a.apk'
const APK_32 = import.meta.env.VITE_APK_URL_32 || 'https://github.com/Raghul2k4/attendly/releases/download/apk32/attendance-1.0.0-armeabi-v7a.apk'

function Nav() {
  return (
    <nav className="navbar">
      <div className="container navbar-content">
        <div className="brand">
          <img src="/icon.png" alt="Attendly logo" className="brand-img" loading="eager" />
          <span className="brand-name">Attendly</span>
        </div>
        <div className="nav-links">
          <a href="#about">About</a>
          <a href="#how-it-works">How it works</a>
          <a href="#features">Features</a>
          <a href="#tech">Tech stack</a>
          <a href="#download">Download</a>
        </div>
        <div className="nav-actions">
          <button className="btn-primary">
            <span className="material-symbols-outlined">download</span>
            Get the app
          </button>
        </div>
      </div>
    </nav>
  )
}

function Hero() {
  return (
    <section className="relative" style={{ paddingTop: '80px' }}>
      <div className="container">
        <div className="glass-strong fade-up" style={{ padding: '3rem 2rem', borderRadius: '2rem' }}>
          <div className="flex flex-col items-center text-center gap-3">
            <span className="chip-free fade-up fade-up-2">
              <span className="material-symbols-outlined" style={{ fontSize: '16px' }}>&nbsp;</span>
              Totally free — no subscription, no per-seat fee
            </span>
            <h1 className="h1 fade-up fade-up-2">
              Transparent attendance<br />
              for small teams
            </h1>
            <p className="text-lead max-w-xl fade-up fade-up-3">
              Owner + employee time tracking with GPS geofence verification,
              workplace QR codes, and real attendance records. Set up in
              minutes — punch in with one tap. No wall clock, no hardware, no
              fees.
            </p>
            <div className="download-btns fade-up fade-up-3">
              <a
                href={APK_64}
                download
                className="btn-primary btn"
              >
                <span className="material-symbols-outlined">download</span>
                Download 64-bit APK (Android)
              </a>
              <a
                href={APK_32}
                download
                className="btn-ghost btn"
              >
                <span className="material-symbols-outlined">download</span>
                Download 32-bit APK (Android)
              </a>
            </div>
            <p className="text-muted text-sm fade-up fade-up-4">
              Version {APP_VERSION} (build {BUILD_NUMBER}) &bull; Released
              {CURRENT_DATE} &bull; Direct file download — no app store required
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}

function About() {
  return (
    <section id="about" className="section">
      <div className="container">
        <div className="section-header fade-up">
          <span className="kicker">The truth about Attendly</span>
          <h2 className="h2">Honest attendance. No hidden costs.</h2>
          <p>
            Attendly is built for small shops, cafes, clinics, gyms, and
            offices that need reliable time tracking without expensive HR
            software. Every record lives on your own Supabase-backed backend
            with Row Level Security — your data stays isolated per
            organisation, and nothing is faked.
          </p>
        </div>
        <div className="glass fade-up fade-up-2" style={{ padding: '2.5rem', borderRadius: '1.5rem' }}>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <h3 className="h3">Who it's for</h3>
              <ul className="list-disc pl-6 mt-2 space-y-2 text-lead text-muted">
                <li>Business owners managing small teams</li>
                <li>Employees who punch in/out by phone</li>
                <li>Shops with a workplace geofence</li>
                <li>Teams wanting location-verified attendance</li>
              </ul>
            </div>
            <div>
              <h3 className="h3">What it is NOT</h3>
              <ul className="list-disc pl-6 mt-2 space-y-2 text-lead text-muted">
                <li>Not a payroll processor</li>
                <li>Not background GPS tracking</li>
                <li>Not a fake demo — real records, real rules</li>
                <li>Not a paywall — free plan is free forever</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

const ownerSteps = [
  {
    title: 'Create your organisation',
    body: 'Sign up as "I own a business," name your organisation, and set your timezone.',
  },
  {
    title: 'Add your workplace',
    body: 'Drop a pin on the map, set the geofence radius, and generate a workplace QR code.',
  },
  {
    title: 'Configure attendance rules',
    body: 'Choose app-button and/or QR punching, set workdays, start time, and late grace period.',
  },
  {
    title: 'Invite your team',
    body: 'Issue permanent staff codes and one-time invite tokens. Share them with your employees.',
  },
  {
    title: 'Monitor from the dashboard',
    body: 'See who is present, checked in, late, or has no record — all from real database records.',
  },
]

const employeeSteps = [
  {
    title: 'Install & sign in',
    body: 'Download the APK, sign in, and open the app.',
  },
  {
    title: 'Join your organisation',
    body: 'Enter the staff code your owner gave you and join securely.',
  },
  {
    title: 'Punch in',
    body: 'Tap Punch In (app button) or scan the workplace QR. GPS is verified once at punch time.',
  },
  {
    title: 'Work your shift',
    body: 'Your session duration tracks live while you are checked in.',
  },
  {
    title: 'Punch out & review',
    body: 'Punch out when finished. View your full attendance history anytime.',
  },
]

function StepGuide({ role, color, steps, icon }) {
  return (
    <div className="glass fade-up" style={{ padding: '2.5rem', borderRadius: '1.5rem' }}>
      <div className="guide-header fade-up fade-up-2">
        <span className="role-badge" style={{ background: `${color}1a`, color }}>
          {role}
        </span>
        <h2 className="h2">{role} step-by-step</h2>
        <p className="text-lead text-muted">
          Everything you need to get running — from first install to first
          verified punch.
        </p>
      </div>
      <div className="steps">
        {steps.map((step, i) => (
          <div key={step.title} className="step-card fade-up" style={{ animationDelay: `${0.2 + i * 0.08}s` }}>
            <div className="step-header">
              <div className="step-number">{i + 1}</div>
              <h3 className="h3">{step.title}</h3>
            </div>
            <p className="text-lead text-muted">{step.body}</p>
          </div>
        ))}
      </div>
    </div>
  )
}

function HowItWorks() {
  return (
    <section id="how-it-works" className="section bg-surface-container-low">
      <div className="container">
        <div className="section-header fade-up">
          <span className="kicker">How it works</span>
          <h2 className="h2">Two roles, one clear flow</h2>
          <p>
            Owners set up the workplace and invite staff. Employees join with a
            staff code and punch in/out. Every punch is validated server-side.
          </p>
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <StepGuide
            role="Owner"
            color="#047857"
            steps={ownerSteps}
            icon="storefront"
          />
          <StepGuide
            role="Employee"
            color="#0f766e"
            steps={employeeSteps}
            icon="badge"
          />
        </div>
      </div>
    </section>
  )
}

function Features() {
  const items = [
    {
      icon: 'access_time',
      title: 'Punch in / out',
      body: 'One-tap attendance with server-side validation of method, geofence, and session state.',
    },
    {
      icon: 'location_on',
      title: 'Geofence verification',
      body: 'GPS is checked only at punch time (~1.2s). We never track background movement.',
    },
    {
      icon: 'qr_code',
      title: 'Workplace QR scanner',
      body: 'Scan the workplace QR — random, revocable identifier, no private data embedded.',
    },
    {
      icon: 'shield',
      title: 'Row Level Security',
      body: 'Every table is RLS-protected. Employees cannot see other organisations or staff records.',
    },
    {
      icon: 'group',
      title: 'Staff management',
      body: 'Owners invite employees with permanent staff codes and manage active/inactive status.',
    },
    {
      icon: 'history',
      title: 'Attendance history',
      body: 'Employees view only their own history. Owners view authorised staff attendance.',
    },
  ]

  return (
    <section id="features" className="section">
      <div className="container">
        <div className="section-header fade-up">
          <span className="kicker">Features</span>
          <h2 className="h2">Everything you need, nothing you don't</h2>
          <p>
            Real attendance records, real validation, and a clean premium
            interface — no dead buttons or placeholder screens.
          </p>
        </div>
        <div className="features">
          {items.map((item, i) => (
            <div key={item.icon} className="feature-card fade-up" style={{ animationDelay: `${0.1 + i * 0.08}s` }}>
              <div className="feature-icon">
                <span className="material-symbols-outlined">{item.icon}</span>
              </div>
              <h3 className="h3">{item.title}</h3>
              <p className="text-lead text-muted">{item.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

function TechStack() {
  return (
    <section id="tech" className="section bg-surface-container-low">
      <div className="container">
        <div className="section-header fade-up">
          <span className="kicker">Built with modern technology</span>
          <h2 className="h2">Current stack as of {CURRENT_DATE}</h2>
          <p>
            Stable, maintained dependencies. Correctness first — no AI bolted
            onto the attendance workflow.
          </p>
        </div>
        <div className="glass fade-up fade-up-2" style={{ padding: '2.5rem', borderRadius: '1.5rem' }}>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-1">
            {[
              'Flutter 3.x',
              'Dart 3.x',
              'Supabase Auth',
              'Supabase PostgreSQL',
              'Riverpod 3.x',
              'GoRouter 18.x',
              'flutter_map',
              'geolocator',
              'mobile_scanner',
              'Tailwind CSS v4',
              'React 19',
              'Vite 6.x',
            ].map((tech, i) => (
              <div
                key={tech}
                className="p-3 rounded-lg bg-white border border-outline text-center text-xs font-semibold text-on-surface-variant"
              >
                {tech}
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

function Download() {
  return (
    <section id="download" className="section bg-surface-container-low">
      <div className="container">
        <div className="section-header fade-up">
          <span className="kicker">Download Attendly</span>
          <h2 className="h2">Get the app — totally free</h2>
          <p>
            No subscription, no per-seat fee, no trial. The free plan supports
            up to 15 active employees per organisation.
          </p>
        </div>
        <div className="download-grid">
          <div className="download-card fade-up fade-up-2">
            <div className="download-icon">
              <span className="material-symbols-outlined">phone_android</span>
            </div>
            <h3 className="h3">64-bit (arm64-v8a)</h3>
            <p className="text-lead text-muted">
              For all modern 64-bit Android devices (Android 10+). Recommended.
            </p>
            <div className="download-btns">
              <a
                href={APK_64}
                download
                className="btn-primary btn"
              >
                <span className="material-symbols-outlined">download</span>
                Download 64-bit APK
              </a>
            </div>
            <p className="download-note">
              Version {APP_VERSION} &bull; {CURRENT_DATE} &bull; Direct file,
              no store required
            </p>
          </div>
          <div className="download-card fade-up fade-up-3">
            <div className="download-icon" style={{ background: 'rgba(100, 116, 139, 0.1)', color: '#64748b' }}>
              <span className="material-symbols-outlined">phone_android</span>
            </div>
            <h3 className="h3">32-bit (armeabi-v7a)</h3>
            <p className="text-lead text-muted">
              For older 32-bit Android devices.
            </p>
            <div className="download-btns">
              <a
                href={APK_32}
                download
                className="btn-primary btn"
              >
                <span className="material-symbols-outlined">download</span>
                Download 32-bit APK
              </a>
            </div>
            <p className="download-note">
              Version {APP_VERSION} &bull; {CURRENT_DATE} &bull; Direct file,
              no store required
            </p>
          </div>
        </div>
        <div className="glass mt-6 p-6 text-center fade-up fade-up-4" style={{ borderRadius: '1.5rem' }}>
          <span className="chip-free" style={{ fontSize: '14px', padding: '0.5rem 1rem' }}>
            <span className="material-symbols-outlined" style={{ fontSize: '18px', marginRight: '0.5rem' }}>&nbsp;</span>
            Completely free — no credit card required
          </span>
          <p className="text-lead text-muted mt-3">
            Install the APK directly on your Android device. You may need to
            enable "Install from unknown sources" in your settings.
          </p>
        </div>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer>
      <div className="footer-content">
        <div className="footer-brand">
          <div className="brand" style={{ gap: '0.5rem' }}>
            <img src="/icon.png" alt="logo" className="brand-img" />
            <span className="brand-name">Attendly</span>
          </div>
          <p>
            Transparent, free attendance for small business teams. Version{' '}
            {APP_VERSION} (build {BUILD_NUMBER}) &bull; {CURRENT_DATE}
          </p>
        </div>
        <div className="footer-links">
          <h4>Product</h4>
          <ul>
            <li><a href="#about">About</a></li>
            <li><a href="#how-it-works">How it works</a></li>
            <li><a href="#features">Features</a></li>
          </ul>
        </div>
        <div className="footer-links">
          <h4>Download</h4>
          <ul>
            <li><a href={APK_64} download>64-bit APK</a></li>
            <li><a href={APK_32} download>32-bit APK</a></li>
          </ul>
        </div>
      </div>
      <div className="footer-bottom">
        &copy; {new Date().getFullYear()} Attendly. Totally free attendance for
        small teams. Built with Flutter + Supabase.
      </div>
    </footer>
  )
}

export default function App() {
  return (
    <>
      <Nav />
      <Hero />
      <About />
      <HowItWorks />
      <Features />
      <TechStack />
      <Download />
      <Footer />
    </>
  )
}
