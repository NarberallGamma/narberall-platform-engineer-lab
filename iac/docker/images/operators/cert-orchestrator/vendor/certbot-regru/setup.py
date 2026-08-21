from setuptools import find_packages
from setuptools import setup

from certbot_regru import __version__

install_requires = [
    'acme>=0.21.1',
    'certbot>=0.21.1',
    'requests>=2.9.1',
    'setuptools',
    'zope.interface',
]

with open('README.md', encoding='utf-8') as f:
    long_description = f.read()

setup(
    name='certbot-regru',
    version=__version__,
    description="Reg.ru DNS authenticator plugin for Certbot (vendored in cert-orchestrator)",
    long_description=long_description,
    long_description_content_type='text/markdown',
    url='https://github.com/free2er/certbot-regru',
    author="Max Pryakhin",
    author_email='m.pryakhin@gmail.com',
    license='MIT',
    python_requires='>=3.8',
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Environment :: Plugins',
        'Intended Audience :: System Administrators',
        'License :: OSI Approved :: MIT License',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
        'Topic :: Internet :: WWW/HTTP',
        'Topic :: Security',
        'Topic :: System :: Systems Administration',
    ],
    install_requires=install_requires,
    packages=find_packages(),
    include_package_data=True,
    entry_points={
        'certbot.plugins': [
            'dns = certbot_regru.dns:Authenticator',
        ],
    },
)
